//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

/**
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

extension Doc {
    public func encodeStateAsUpdate(encodedStateVector: Data? = nil, encoder: UpdateEncoder = UpdateEncoderV1()) throws -> Data {
        try encoder.encodeStateAsUpdate(doc: self, encodedStateVector: encodedStateVector)
    }
    
    public func encodeStateAsUpdateV2(encodedStateVector: Data? = nil) throws -> Data {
        try self.encodeStateAsUpdate(encodedStateVector: encodedStateVector, encoder: UpdateEncoderV2())
    }
}

extension UpdateEncoder {
    func writeStructs(structs: Ref<[Struct]>, client: Int, clock: Int) throws {
        // write first id
        let clock = max(clock, structs[0].id.clock) // make sure the first id exists
        let startNewStructs = try StructStore.findIndexSS(structs: structs, clock: clock)
            
        // write # encoded structs
        self.restEncoder.writeUInt(UInt(structs.count - startNewStructs))
        self.writeClient(client)
        self.restEncoder.writeUInt(UInt(clock))
            
        let firstStruct = structs[startNewStructs]
        // write first struct with an offset
        try firstStruct.encode(into: self, offset: clock - firstStruct.id.clock)
        for i in (startNewStructs + 1)..<structs.count {
            try structs[i].encode(into: self, offset: 0)
        }
    }
    
    func writeClientsStructs(store: StructStore, stateVector: [Int: Int]) throws {
        // we filter all valid _sm entries into sm
        var _stateVector = [Int: Int]()
        
        for (client, clock) in stateVector where store.getState(client) > clock {
            _stateVector[client] = clock
        }
        for (client, _) in store.getStateVector() where stateVector[client] == nil {
            _stateVector[client] = 0
        }
            
        self.restEncoder.writeUInt(UInt(_stateVector.count))
        
        for (client, clock) in _stateVector.sorted(by: { $0.key > $1.key }) {
            guard let structs = store.clients[client] else { continue }
            try self.writeStructs(structs: structs, client: client, clock: clock)
        }
    }
    
    func writeStructs(from transaction: Transaction) throws {
        try self.writeClientsStructs(store: transaction.doc.store, stateVector: transaction.beforeState)
    }
    
    func writeStateAsUpdate(doc: Doc, targetStateVector: [Int: Int] = [:]) throws {
        try self.writeClientsStructs(store: doc.store, stateVector: targetStateVector)
        try DeleteSet.createFromStructStore(doc.store).encode(into: self)
    }

    public func encodeStateAsUpdate(doc: Doc, encodedStateVector: Data? = nil) throws -> Data {
        let encoder = self
        
        let encodedStateVector = encodedStateVector ?? Data([0])
        
        let targetStateVector = try decodeStateVector(decodedState: encodedStateVector)
        
        try encoder.writeStateAsUpdate(doc: doc, targetStateVector: targetStateVector)
            
        var updates = [encoder.toData()]
        // also add the pending updates (if there are any)
        
        if doc.store.pendingDs != nil {
            updates.append(doc.store.pendingDs!)
        }
        if doc.store.pendingStructs != nil {
            updates.append(try diffUpdateV2(update: doc.store.pendingStructs!.update, sv: encodedStateVector))
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
}

extension DSEncoder {
    
    public func writeStateVector(_ stateVector: [Int: Int]) throws {
        self.restEncoder.writeUInt(UInt(stateVector.count))
        
        for (client, clock) in stateVector.sorted(by: { $0.key > $1.key }) {
            self.restEncoder.writeUInt(UInt(client))
            self.restEncoder.writeUInt(UInt(clock))
        }

    }
}


public func writeDocumentStateVector(encoder: DSEncoder, doc: Doc) throws {
    return try encoder.writeStateVector(doc.store.getStateVector())
}

public func encodeStateVectorV2(doc: [Int: Int], encoder: DSEncoder = DSEncoderV2()) throws -> Data {
    try encoder.writeStateVector(doc)
    return encoder.toData()
}

public func encodeStateVectorV2(doc: Doc, encoder: DSEncoder = DSEncoderV2()) throws -> Data {
    try writeDocumentStateVector(encoder: encoder, doc: doc)
    return encoder.toData()
}

public func encodeStateVector(doc: Doc) throws -> Data {
    return try encodeStateVectorV2(doc: doc, encoder: DSEncoderV1())
}

public func encodeStateVector(doc: [Int: Int]) throws -> Data {
    return try encodeStateVectorV2(doc: doc, encoder: DSEncoderV1())
}

// ============================================================================================ //
// Decoding //



public func decodeStateVector(decodedState: Data) throws -> [Int: Int] {
    return try readStateVector(decoder: DSDecoderV1(LZDecoder(decodedState)))
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


final class StructRef: CustomStringConvertible {
    var i: Int
    var refs: RefArray<Struct?>
    
    init(i: Int, refs: RefArray<Struct?>) { self.i = i; self.refs = refs }
    
    var description: String { "StructRef(i: \(i), refs: \(refs))" }
}

extension UpdateDecoder {
    func readClientsStructRefs(doc: Doc) throws -> Ref<[Int: StructRef]> {
        let decoder = self // patch
        
        
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
                           ? .object(doc.get(YObject.self, name: decoder.readString(), make: YObject.init))
                           : .id(decoder.readLeftID()))
                        : nil, // parent
                        parentSub: cantCopyParentInfo && (info & 0b0010_0000) == 0b0010_0000 ? decoder.readString() : nil, // parentSub
                        content: try decodeContent(from: decoder, info: info) // item content
                    )
                    refs[i] = struct_
                    clock += struct_.length
                }
            }

        }

        return clientRefs
    }

}

func integrateStructs(transaction: Transaction, store: StructStore, clientsStructRefs: Ref<[Int: StructRef]>) throws -> PendingStrcut? {
    
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
        try encoder.writeClientsStructs(store: restStructs, stateVector: [:])
        // write empty deleteset
        // writeDeleteSet(encoder, DeleteSet())
        encoder.restEncoder.writeUInt(0) // -> no need for an extra function call, just write 0 deletes
        return PendingStrcut(missing: missingSV, update: encoder.toData())
    }
    return nil
}


public func readUpdateV2(decoder: LZDecoder, ydoc: Doc, transactionOrigin: Any?, structDecoder: UpdateDecoder? = nil) throws {
    let structDecoder = try structDecoder ?? UpdateDecoderV2(decoder)
    
    try ydoc.transact(origin: transactionOrigin, local: false) { transaction in
        transaction.local = false
        var retry = false
        let doc = transaction.doc
        
        let store = doc.store
        let uss = try structDecoder.readClientsStructRefs(doc: doc)
        
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
    }
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

