//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

/*
 * We use the first five bits in the info flag for determining the type of the struct.
 *
 * 0: GC
 * 1: Item with Deleted content
 * 2: Item with JSON content
 * 3: Item with Binary content
 * 4: Item with String content
 * 5: Item with Embed content (for richtext content)
 * 6: Item with Format content (a formatting marker for richtext content)
 * 7: Item with Type
 */

public func writeStructs(encoder: UpdateEncoder, structs: Ref<[Struct]>, client: Int, clock: Int) throws {
    // write first id
    let clock = max(clock, structs[0].id.clock) // make sure the first id exists
    let startNewStructs = try StructStore.findIndexSS(structs: structs, clock: clock)
        
    // write # encoded structs
    encoder.restEncoder.writeUInt(UInt(structs.count - startNewStructs))
    encoder.writeClient(client)
    encoder.restEncoder.writeUInt(UInt(clock))
        
    let firstStruct = structs[startNewStructs]
    // write first struct with an offset
    try firstStruct.write(encoder: encoder, offset: clock - firstStruct.id.clock)
    for i in (startNewStructs + 1)..<structs.count {
        try structs[i].write(encoder: encoder, offset: 0)
    }
}

public func writeClientsStructs(encoder: UpdateEncoder, store: StructStore, _sm: [Int: Int]) throws {
    // we filter all valid _sm entries into sm
    var sm = [Int: Int]()
    _sm.forEach({ client, clock in
        // only write if structs are available
        if store.getState(client) > clock {
            sm[client] = clock
        }
    })
    store.getStateVector().forEach({ client, clock in
        if _sm[Int(client)] == nil {
            sm[Int(client)] = 0
        }
    })
        
    // write # states that were updated
    encoder.restEncoder.writeUInt(UInt(sm.count))
    
    try sm.sorted(by: { $0.key > $1.key }).forEach{ client, clock in
        try writeStructs(encoder: encoder, structs: store.clients[client]!, client: client, clock: clock)
    }
}

public class StructRef: CustomStringConvertible {
    public var i: Int
    public var refs: RefArray<Struct?>
    
    init(i: Int, refs: RefArray<Struct?>) {
        self.i = i
        self.refs = refs
    }
    
    public var description: String { "StructRef(i: \(i), refs: \(refs))" }
}

public func readClientsStructRefs(decoder: UpdateDecoder, doc: Doc) throws -> Ref<[Int: StructRef]> {
    let clientRefs = Ref<[Int: StructRef]>(value: [:])
    let numOfStateUpdates = try Int(decoder.restDecoder.readUInt())
    
    for _ in 0..<numOfStateUpdates {
        let numberOfStructs = try Int(decoder.restDecoder.readUInt())
        let refs = RefArray<Struct?>(repeating: nil, count: numberOfStructs)
        let client = try decoder.readClient()
        var clock = try Int(decoder.restDecoder.readUInt())
        
        clientRefs.value[client] = StructRef(i: 0, refs: refs)
                
        for i in 0..<numberOfStructs {
            let info = try decoder.readInfo()
            let contentType = info & 0b0001_1111
            
            assert((0...10).contains(contentType))
            
            switch contentType {
            case 0:
                let len = try decoder.readLen()
                refs[i] = GC(id: ID(client: client, clock: clock), length: len)
                clock += len
            case 10:
                let len = try Int(decoder.restDecoder.readUInt())
                refs[i] = Skip(id: ID(client: client, clock: clock), length: len)
                clock += len
                break
            default:
                let cantCopyParentInfo = (info & (0b0100_0000 | 0b1000_0000)) == 0
                let struct_ = try Item(
                    id: ID(client: client, clock: clock),
                    left: nil,
                    origin: (info & 0b1000_0000) == 0b1000_0000 ? decoder.readLeftID() : nil, // origin
                    right: nil,
                    rightOrigin: (info & 0b0100_0000) == 0b0100_0000 ? decoder.readRightID() : nil, // right origin
                    parent: cantCopyParentInfo
                    ? (decoder.readParentInfo()
                       ? .object(doc.get(YCObject.self, name: decoder.readString(), make: YCObject.init))
                       : .id(decoder.readLeftID()))
                    : nil, // parent
                    parentSub: cantCopyParentInfo && (info & 0b0010_0000) == 0b0010_0000 ? decoder.readString() : nil, // parentSub
                    content: try decodeContent(from: decoder, info: info) // item content
                )
                refs[i] = struct_
                clock += struct_.length
            }
        }
        // console.log('time to read: ', performance.now() - start) // @todo remove
    }

    return clientRefs
}

public func integrateStructs(
    transaction: Transaction,
    store: StructStore,
    clientsStructRefs: Ref<[Int: StructRef]>
) throws -> PendingStrcut? {
    var stack: [Struct] = []
    var clientsStructRefsIds = clientsStructRefs.value.keys.sorted(by: <)
    if clientsStructRefsIds.count == 0 {
        return nil
    }
    
    func getNextStructTarget() -> StructRef? {
        if clientsStructRefsIds.count == 0 {
            return nil
        }
        var nextStructsTarget = clientsStructRefs.value[clientsStructRefsIds.last!]!
            
        while nextStructsTarget.refs.count == nextStructsTarget.i {
            clientsStructRefsIds.removeLast()
            if clientsStructRefsIds.count > 0 {
                nextStructsTarget = clientsStructRefs.value[clientsStructRefsIds.last!]!
            } else {
                return nil
            }
        }
        return nextStructsTarget
    }
    var curStructsTarget = getNextStructTarget()
    if curStructsTarget == nil && stack.count == 0 {
        return nil
    }

    let restStructs: StructStore = StructStore()
    var missingSV = [Int: Int]()
    func updateMissingSv(client: Int, clock: Int) {
        let mclock = missingSV[client]
        if mclock == nil || mclock! > clock {
            missingSV[client] = clock
        }
    }

    var stackHead: Struct = curStructsTarget!.refs.value[curStructsTarget!.i]!
    curStructsTarget!.i += 1
    var state = [Int: Int]()

    func addStackToRestSS() {
        for item in stack {
            let client = item.id.client
            let unapplicableItems = clientsStructRefs.value[client]
            if unapplicableItems != nil {
                // decrement because we weren't able to apply previous operation
                unapplicableItems!.i -= 1
                restStructs.clients[client] = Ref(
                    value: unapplicableItems!.refs[unapplicableItems!.i...].map{ $0! }
                )
                clientsStructRefs.value.removeValue(forKey: client)
                unapplicableItems!.i = 0
                unapplicableItems!.refs = []
            } else {
                // item was the last item on clientsStructRefs and the field was already cleared. Add item to restStructs and continue
                restStructs.clients[client] = .init(value: [item])
            }
            // remove client from clientsStructRefsIds to prevent users from applying the same update again
            clientsStructRefsIds = clientsStructRefsIds.filter{ $0 != client }
        }
        stack.removeAll()
    }

    // iterate over all struct readers until we are done
    while (true) {
        if type(of: stackHead) != Skip.self {
            let localClock = state.setIfUndefined(stackHead.id.client, store.getState(stackHead.id.client))
            let offset = localClock - stackHead.id.clock
            if offset < 0 {
                stack.append(stackHead)
                updateMissingSv(client: stackHead.id.client, clock: stackHead.id.clock - 1)
                // hid a dead wall, add all items from stack to restSS
                addStackToRestSS()
            } else {
                let missing = try stackHead.getMissing(transaction, store: store)
                if missing != nil {
                    stack.append(stackHead)
                    
                    let structRefs: StructRef = clientsStructRefs.value[missing!] ?? StructRef(i: 0, refs: [])
                    
                    if structRefs.refs.count == structRefs.i {
                        updateMissingSv(client: missing!, clock: store.getState(missing!))
                        addStackToRestSS()
                    } else {
                        stackHead = structRefs.refs.value[structRefs.i]!
                        structRefs.i += 1
                        continue
                    }
                } else if offset == 0 || offset < stackHead.length {
                    // all fine, apply the stackhead
                    try stackHead.integrate(transaction: transaction, offset: offset)
                    state[stackHead.id.client] = stackHead.id.clock + stackHead.length
                }
            }
        }
        // iterate to next stackHead
        if stack.count > 0 {
            stackHead = stack.removeLast()
        } else if curStructsTarget != nil && curStructsTarget!.i < curStructsTarget!.refs.count {
            stackHead = curStructsTarget!.refs.value[curStructsTarget!.i]!
            curStructsTarget!.i += 1
        } else {
            curStructsTarget = getNextStructTarget()
                        
            if curStructsTarget == nil {
                // we are done!
                break
            } else {
                stackHead = curStructsTarget!.refs.value[curStructsTarget!.i]!
                curStructsTarget!.i += 1
            }
        }
    }
    
    if restStructs.clients.count > 0 {
        let encoder = UpdateEncoderV2()
        try writeClientsStructs(encoder: encoder, store: restStructs, _sm: [:])
        // write empty deleteset
        // writeDeleteSet(encoder, DeleteSet())
        encoder.restEncoder.writeUInt(0) // -> no need for an extra function call, just write 0 deletes
        return PendingStrcut(missing: missingSV, update: encoder.toData())
    }
    return nil
}


public func writeStructsFromTransaction(encoder: UpdateEncoder, transaction: Transaction) throws {
    try writeClientsStructs(
        encoder: encoder,
        store: transaction.doc.store,
        _sm: transaction.beforeState
    )
}

public func readUpdateV2(decoder: LZDecoder, ydoc: Doc, transactionOrigin: Any?, structDecoder: UpdateDecoder? = nil) throws {
    let structDecoder = try structDecoder ?? UpdateDecoderV2(decoder)
    
    try ydoc.transact({ transaction in
        transaction.local = false
        var retry = false
        let doc = transaction.doc
        
        let store = doc.store
        let uss = try readClientsStructRefs(decoder: structDecoder, doc: doc)
        
        let restStructs = try integrateStructs(transaction: transaction, store: store, clientsStructRefs: uss)
                
        let pending = store.pendingStructs
        if (pending != nil) {
            // check if we can apply something
            for (client, clock) in pending!.missing {
                if clock < store.getState(client) {
                    retry = true
                    break
                }
            }
            if (restStructs != nil) {
                // merge restStructs into store.pending
                for (client, clock) in restStructs!.missing {
                    let mclock = pending!.missing[client]
                    if mclock == nil || mclock! > clock {
                        pending!.missing[client] = clock
                    }
                }
                pending!.update = try mergeUpdatesV2(updates: [pending!.update, restStructs!.update])
            }
        } else {
            store.pendingStructs = restStructs
        }

        let dsRest = try DeleteSet.decodeAndApply(structDecoder, transaction: transaction, store: store)
        
        if store.pendingDs != nil {
            let pendingDSUpdate = try UpdateDecoderV2(LZDecoder(store.pendingDs!))
            _ = try pendingDSUpdate.restDecoder.readUInt() // read 0 structs, because we only encode deletes in pendingdsupdate
            let dsRest2 = try DeleteSet.decodeAndApply(pendingDSUpdate, transaction: transaction, store: store)
            if dsRest != nil && dsRest2 != nil {
                store.pendingDs = try mergeUpdatesV2(updates: [dsRest!, dsRest2!])
            } else {
                store.pendingDs = dsRest ?? dsRest2
            }
        } else {
            // Either dsRest == nil && pendingDs == nil OR dsRest != nil
            store.pendingDs = dsRest
        }
        
        if retry {
            let update = store.pendingStructs!.update
            store.pendingStructs = nil
            try applyUpdateV2(ydoc: transaction.doc, update: update, transactionOrigin: nil)
        }
    }, origin: transactionOrigin, local: false)
}

public func readUpdate(decoder: LZDecoder, ydoc: Doc, transactionOrigin: Any? = nil) throws {
    return try readUpdateV2(decoder: decoder, ydoc: ydoc, transactionOrigin: transactionOrigin, structDecoder: UpdateDecoderV1(decoder))
}

public func applyUpdateV2(ydoc: Doc, update: Data, transactionOrigin: Any? = nil, YDecoder: (LZDecoder) throws -> UpdateDecoder = { try UpdateDecoderV2($0) }) throws {
    let decoder = LZDecoder(update)
    try readUpdateV2(decoder: decoder, ydoc: ydoc, transactionOrigin: transactionOrigin, structDecoder: try YDecoder(decoder))
}

public func applyUpdate(ydoc: Doc, update: Data, transactionOrigin: Any? = nil) throws {
    return try applyUpdateV2(ydoc: ydoc, update: update, transactionOrigin: transactionOrigin, YDecoder: UpdateDecoderV1.init)
}

public func writeStateAsUpdate(encoder: UpdateEncoder, doc: Doc, targetStateVector: [Int: Int] = [:]) throws {
    try writeClientsStructs(encoder: encoder, store: doc.store, _sm: targetStateVector)
    try DeleteSet.createFromStructStore(doc.store).encode(encoder)
}

public func encodeStateAsUpdateV2(doc: Doc, encodedTargetStateVector: Data? = nil, encoder: UpdateEncoder = UpdateEncoderV2()) throws -> Data {
    let encodedTargetStateVector = encodedTargetStateVector ?? Data([0])
    
    let targetStateVector = try decodeStateVector(decodedState: encodedTargetStateVector)
    
    try writeStateAsUpdate(encoder: encoder, doc: doc, targetStateVector: targetStateVector)
        
    var updates = [encoder.toData()]
    // also add the pending updates (if there are any)
    
    if doc.store.pendingDs != nil {
        updates.append(doc.store.pendingDs!)
    }
    if doc.store.pendingStructs != nil {
        updates.append(try diffUpdateV2(update: doc.store.pendingStructs!.update, sv: encodedTargetStateVector))
    }
    
    
    if updates.count > 1 {
        if encoder is UpdateEncoderV1 {
            return try mergeUpdates(updates: updates.enumerated().map{ i, update in
                try i == 0 ? update : convertUpdateFormatV2ToV1(update: update)
            })
        } else if encoder is UpdateEncoderV2 {
            return try mergeUpdatesV2(updates: updates)
        }
    }

    return updates[0]
}

public func encodeStateAsUpdate(doc: Doc, encodedTargetStateVector: Data? = nil) throws -> Data {
    return try encodeStateAsUpdateV2(doc: doc, encodedTargetStateVector: encodedTargetStateVector, encoder: UpdateEncoderV1())
}

public func readStateVector(decoder: DSDecoder) throws -> [Int: Int] {
    var ss = [Int:Int]()
    let ssLength = try decoder.restDecoder.readUInt()
    for _ in 0..<ssLength {
        let client = try decoder.restDecoder.readUInt()
        let clock = try decoder.restDecoder.readUInt()
        
        ss[Int(client)] = Int(clock)
    }
    return ss
}

public func decodeStateVector(decodedState: Data) throws -> [Int: Int] {
    return try readStateVector(decoder: DSDecoderV1(LZDecoder(decodedState)))
}

public func writeStateVector(encoder: DSEncoder, sv: [Int: Int]) throws -> DSEncoder {
    encoder.restEncoder.writeUInt(UInt(sv.count))
    sv.sorted(by: { $0.key > $1.key }).forEach{ client, clock in
        encoder.restEncoder.writeUInt(UInt(client))
        encoder.restEncoder.writeUInt(UInt(clock))
    }
    return encoder
}

public func writeDocumentStateVector(encoder: DSEncoder, doc: Doc) throws -> DSEncoder {
    return try writeStateVector(encoder: encoder, sv: doc.store.getStateVector())
}

public func encodeStateVectorV2(doc: [Int: Int], encoder: DSEncoder = DSEncoderV2()) throws -> Data {
    try _ = writeStateVector(encoder: encoder, sv: doc)
    return encoder.toData()
}

public func encodeStateVectorV2(doc: Doc, encoder: DSEncoder = DSEncoderV2()) throws -> Data {
    try _ = writeDocumentStateVector(encoder: encoder, doc: doc)
    return encoder.toData()
}

public func encodeStateVector(doc: Doc) throws -> Data {
    return try encodeStateVectorV2(doc: doc, encoder: DSEncoderV1())
}

public func encodeStateVector(doc: [Int: Int]) throws -> Data {
    return try encodeStateVectorV2(doc: doc, encoder: DSEncoderV1())
}

extension Dictionary where Key == Int, Value == Int {
    func toUIntUInt() -> [UInt: UInt] {
        .init(self.map{ (UInt($0), UInt($1)) }, uniquingKeysWith: { k, _ in k })
    }
}

extension Dictionary where Key == UInt, Value == UInt {
    func toIntInt() -> [Int: Int] {
        .init(self.map{ (Int($0), Int($1)) }, uniquingKeysWith: { k, _ in k })
    }
}
