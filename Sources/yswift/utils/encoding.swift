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

public func writeStructs(encoder: UpdateEncoder, structs: [GC_or_Item], client: UInt, clock: UInt) {
    // write first id
    let clock = max(clock, structs[0].id.clock) // make sure the first id exists
    let startNewStructs = StructStore.findIndexSS(structs, clock)
    // write # encoded structs
    encoder.restEncoder.writeUInt(structs.length - startNewStructs)
    encoder.writeClient(client)
    encoder.restEncoder.writeUInt(clock)
    let firstStruct = structs[startNewStructs]
    // write first struct with an offset
    firstStruct.write(encoder, clock - firstStruct.id.clock)
    public func for(_ var i = startNewStructs + 1; i < structs.length; i++) {
        structs[i].write(encoder, 0)
    }
}

public func writeClientsStructs(encoder: UpdateEncoderV1 | UpdateEncoderV2, store: StructStore, _sm: [Int: Int]) {
    // we filter all valid _sm entries into sm
    let sm = [:]
    _sm.forEach((clock, client) -> {
        // only write if structs are available
        if store.getState(client) > clock {
            sm.set(client, clock)
        }
    })
    store.getStateVector().forEach((clock, client) -> {
        if !_sm.has(client) {
            sm.set(client, 0)
        }
    })
    // write # states that were updated
    encoder.restEncoder.writeUInt(sm.size)
    // Write items with higher client ids first
    // This heavily improves the conflict algorithm.
    Array.from(sm.entries()).sort((a, b) -> b[0] - a[0]).forEach(([client, clock]) -> {
        writeStructs(encoder, store.clients.get(client) ?? [], client, clock)
    })
}

public func readClientsStructRefs(decoder: UpdateDecoderAny_, doc: Doc) -> Map<Int, { i: Int; refs: Array<Item | GC> }> {
    let clientRefs = Map<Int, { i: Int; refs: Array<Item | GC> }>()
    let numOfStateUpdates = decoder.restDecoder.readUInt()
    public func for(_ var i = 0; i < numOfStateUpdates; i++) {
        let IntOfStructs = decoder.restDecoder.readUInt()
        /**
         * @type {Array<GC|Item>}
         */
        let refs: Array<GC | Item> = Array(IntOfStructs)
        let client = decoder.readClient()
        var clock = decoder.restDecoder.readUInt()
        // let start = performance.now()
        clientRefs.set(client, { i: 0, refs })
        public func for(_ var i = 0; i < IntOfStructs; i++) {
            let info = decoder.readInfo()
            public func switch(_ Lib0Bits.n5 & info) {
                case 0: { // GC
                    let len = decoder.readLen()
                    refs[i] = GC(ID(client, clock), len)
                    clock += len
                    break
                }
                case 10: { // Skip Struct (nothing to apply)
                    // @todo we could reduce the amount of checks by adding Skip struct to clientRefs so we know that something is missing.
                    let len = decoder.restDecoder.readUInt()
                    refs[i] = Skip(ID(client, clock), len)
                    clock += len
                    break
                }
                default: { // Item with content
                    /**
                     * The optimized implementation doesn't use any variables because inlining variables is faster.
                     * Below a non-optimized version is shown that implements the basic algorithm with
                     * a few comments
                     */
                    let cantCopyParentInfo = (info & (Lib0Bit.n7 | Lib0Bit.n8)) == 0
                    // If parent = nil and neither left nor right are defined, then we know that `parent` is child of `y`
                    // and we read the next String as parentYKey.
                    // It indicates how we store/retrieve parent from `y.share`
                    // @type {String?}
                    let struct = Item(
                        ID(client, clock),
                        nil, // leftd
                        (info & Lib0Bit.n8) == Lib0Bit.n8 ? decoder.readLeftID() : nil, // origin
                        nil, // right
                        (info & Lib0Bit.n7) == Lib0Bit.n7 ? decoder.readRightID() : nil, // right origin
                        cantCopyParentInfo ? (decoder.readParentInfo() ? doc.get(decoder.readString()) : decoder.readLeftID()) : nil, // parent
                        cantCopyParentInfo && (info & Lib0Bit.n6) == Lib0Bit.n6 ? decoder.readString() : nil, // parentSub
                        readItemContent(decoder, info) // item content
                    )
                    /* A non-optimized implementation of the above algorithm:

                    // The item that was originally to the left of this item.
                    let origin = (info & binary.BIT8) == binary.BIT8 ? decoder.readLeftID() : nil
                    // The item that was originally to the right of this item.
                    let rightOrigin = (info & binary.BIT7) == binary.BIT7 ? decoder.readRightID() : nil
                    let cantCopyParentInfo = (info & (binary.BIT7 | binary.BIT8)) == 0
                    let hasParentYKey = cantCopyParentInfo ? decoder.readParentInfo() : false
                    // If parent = nil and neither left nor right are defined, then we know that `parent` is child of `y`
                    // and we read the next String as parentYKey.
                    // It indicates how we store/retrieve parent from `y.share`
                    // @type {String?}
                    let parentYKey = cantCopyParentInfo && hasParentYKey ? decoder.readString() : nil

                    let struct = Item(
                        ID(client, clock),
                        nil, // leftd
                        origin, // origin
                        nil, // right
                        rightOrigin, // right origin
                        cantCopyParentInfo && !hasParentYKey ? decoder.readLeftID() : (parentYKey != nil ? doc.get(parentYKey) : nil), // parent
                        cantCopyParentInfo && (info & binary.BIT6) == binary.BIT6 ? decoder.readString() : nil, // parentSub
                        readItemContent(decoder, info) // item content
                    )
                    */
                    refs[i] = struct
                    clock += struct.length
                }
            }
        }
        // console.log('time to read: ', performance.now() - start) // @todo remove
    }
    return clientRefs
}

public func integrateStructs(transaction: Transaction, store: StructStore, clientsStructRefs: Map<Int, { i: Int; refs: (GC | Item)[] }>) -> nil | { update: Data; missing: [Int: Int] } {
    /**
     * @type {Array<Item | GC>}
     */
    let stack: Array<Item | GC> = []
    // sort them so that we take the higher id first, in case of conflicts the lower id will probably not conflict with the id from the higher user.
    var clientsStructRefsIds = Array.from(clientsStructRefs.keys()).sort((a, b) -> a - b)
    if clientsStructRefsIds.length == 0 {
        return nil
    }
    let getNextStructTarget = () -> {
        if clientsStructRefsIds.length == 0 {
            return nil
        }
        var nextStructsTarget = (clientsStructRefs.get(clientsStructRefsIds[clientsStructRefsIds.length - 1]) as { i: Int, refs: Array<GC|Item> })
        while (nextStructsTarget.refs.length == nextStructsTarget.i) {
            clientsStructRefsIds.pop()
            if clientsStructRefsIds.length > 0 {
                nextStructsTarget = (clientsStructRefs.get(clientsStructRefsIds[clientsStructRefsIds.length - 1])) as { i: Int, refs: Array<GC|Item> }
            } else {
                return nil
            }
        }
        return nextStructsTarget
    }
    var curStructsTarget = getNextStructTarget()
    if curStructsTarget == nil && stack.length == 0 {
        return nil
    }

    /**
     * @type {StructStore}
     */
    let restStructs: StructStore = StructStore()
    let missingSV = [:]
    /**
     * @param {Int} client
     * @param {Int} clock
     */
    let updateMissingSv = (client: Int, clock: Int) -> {
        let mclock = missingSV.get(client)
        if mclock == nil || mclock > clock {
            missingSV.set(client, clock)
        }
    }
    /**
     * @type {GC|Item}
     */
    var stackHead: GC | Item = (curStructsTarget as any).refs[(curStructsTarget as any).i++]
    // caching the state because it is used very often
    let state = [:]

    let addStackToRestSS = () -> {
        public func for(_ let item of stack) {
            let client = item.id.client
            let unapplicableItems = clientsStructRefs.get(client)
            if unapplicableItems {
                // decrement because we weren't able to apply previous operation
                unapplicableItems.i--
                restStructs.clients.set(client, unapplicableItems.refs.slice(unapplicableItems.i))
                clientsStructRefs.delete(client)
                unapplicableItems.i = 0
                unapplicableItems.refs = []
            } else {
                // item was the last item on clientsStructRefs and the field was already cleared. Add item to restStructs and continue
                restStructs.clients.set(client, [item])
            }
            // remove client from clientsStructRefsIds to prevent users from applying the same update again
            clientsStructRefsIds = clientsStructRefsIds.filter(c -> c != client)
        }
        stack.length = 0
    }

    // iterate over all struct readers until we are done
    while (true) {
        if stackHead.constructor != Skip {
            let localClock = Lib0setIfUndefined(state, stackHead.id.client, () -> store.getState(stackHead.id.client))
            let offset = localClock - stackHead.id.clock
            if offset < 0 {
                // update from the same client is missing
                stack.push(stackHead)
                updateMissingSv(stackHead.id.client, stackHead.id.clock - 1)
                // hid a dead wall, add all items from stack to restSS
                addStackToRestSS()
            } else {
                let missing = stackHead.getMissing(transaction, store)
                if missing != nil {
                    stack.push(stackHead)
                    // get the struct reader that has the missing struct
                    
                    let structRefs: { refs: Array<GC | Item>, i: Int } = clientsStructRefs.get(missing) || { refs: [], i: 0 }

                    if structRefs.refs.length == structRefs.i {
                        // This update message causally depends on another update message that doesn't exist yet
                        updateMissingSv( (missing), store.getState(missing))
                        addStackToRestSS()
                    } else {
                        stackHead = structRefs.refs[structRefs.i++]
                        continue
                    }
                } else if offset == 0 || offset < stackHead.length {
                    // all fine, apply the stackhead
                    stackHead.integrate(transaction, offset)
                    state.set(stackHead.id.client, stackHead.id.clock + stackHead.length)
                }
            }
        }
        // iterate to next stackHead
        if stack.length > 0 {
            stackHead =  (stack.pop()) as GC|Item
        } else if curStructsTarget != nil && curStructsTarget.i < curStructsTarget.refs.length {
            stackHead = (curStructsTarget.refs[curStructsTarget.i++]) as GC|Item
        } else {
            curStructsTarget = getNextStructTarget()
            if curStructsTarget == nil {
                // we are done!
                break
            } else {
                stackHead = (curStructsTarget.refs[curStructsTarget.i++]) as GC|Item
            }
        }
    }
    if restStructs.clients.size > 0 {
        let encoder = UpdateEncoderV2()
        writeClientsStructs(encoder, restStructs, [:])
        // write empty deleteset
        // writeDeleteSet(encoder, DeleteSet())
        encoder.restEncoder.writeUInt(0) // -> no need for an extra function call, just write 0 deletes
        return { missing: missingSV, update: encoder.data }
    }
    return nil
}


public func writeStructsFromTransaction(encoder: UpdateEncoderV1 | UpdateEncoderV2, transaction: Transaction) -> {
    return writeClientsStructs(encoder, transaction.doc.store, transaction.beforeState)
}

public func readUpdateV2(decoder: Lib0Decoder, ydoc: Doc, transactionOrigin: any, structDecoder: UpdateDecoderV1 | UpdateDecoderV2 = UpdateDecoderV2(decoder)) {
    ydoc.transact(transaction -> {
        // force that transaction.local is set to non-local
        transaction.local = false
        var retry = false
        let doc = transaction.doc
        let store = doc.store
        // var start = performance.now()
        let ss = readClientsStructRefs(structDecoder, doc)
        // console.log('time to read structs: ', performance.now() - start) // @todo remove
        // start = performance.now()
        // console.log('time to merge: ', performance.now() - start) // @todo remove
        // start = performance.now()
        let restStructs = integrateStructs(transaction, store, ss)
        let pending = store.pendingStructs
        if pending {
            // check if we can apply something
            public func for(_ let [client, clock] of pending.missing) {
                if clock < store.getState(client) {
                    retry = true
                    break
                }
            }
            if restStructs {
                // merge restStructs into store.pending
                public func for(_ let [client, clock] of restStructs.missing) {
                    let mclock = pending.missing.get(client)
                    if mclock == nil || mclock > clock {
                        pending.missing.set(client, clock)
                    }
                }
                pending.update = mergeUpdatesV2([pending.update, restStructs.update])
            }
        } else {
            store.pendingStructs = restStructs
        }
        // console.log('time to integrate: ', performance.now() - start) // @todo remove
        // start = performance.now()
        let dsRest = DeleteSet.decodeAndApply(structDecoder, transaction, store)
        if store.pendingDs {
            // @todo we could make a lower-bound state-vector check as we do above
            let pendingDSUpdate = UpdateDecoderV2(Lib0Decoder(store.pendingDs))
            pendingDSUpdate.restDecoder.readUInt() // read 0 structs, because we only encode deletes in pendingdsupdate
            let dsRest2 = DeleteSet.decodeAndApply(pendingDSUpdate, transaction, store)
            if dsRest && dsRest2 {
                // case 1: ds1 != nil && ds2 != nil
                store.pendingDs = mergeUpdatesV2([dsRest, dsRest2])
            } else {
                // case 2: ds1 != nil
                // case 3: ds2 != nil
                // case 4: ds1 == nil && ds2 == nil
                store.pendingDs = dsRest || dsRest2
            }
        } else {
            // Either dsRest == nil && pendingDs == nil OR dsRest != nil
            store.pendingDs = dsRest
        }
        // console.log('time to cleanup: ', performance.now() - start) // @todo remove
        // start = performance.now()

        // console.log('time to resume delete readers: ', performance.now() - start) // @todo remove
        // start = performance.now()
        if retry {
            let update = (store.pendingStructs as {update: Data}).update
            store.pendingStructs = nil
            applyUpdateV2(transaction.doc, update)
        }
    }, transactionOrigin, false)
}

public func readUpdate(decoder: Lib0Decoder, ydoc: Doc, transactionOrigin: any) {
    return readUpdateV2(decoder, ydoc, transactionOrigin, UpdateDecoderV1(decoder))
}

public func applyUpdateV2(ydoc: Doc, update: Data, transactionOrigin?: any, YDecoder: typeof UpdateDecoderV1 | typeof UpdateDecoderV2 = UpdateDecoderV2) {
    let decoder = Lib0Decoder(update)
    readUpdateV2(decoder, ydoc, transactionOrigin, YDecoder(decoder))
}

public func applyUpdate(ydoc: Doc, update: Data, transactionOrigin?: any) {
    return applyUpdateV2(ydoc, update, transactionOrigin, UpdateDecoderV1)
}

public func writeStateAsUpdate(encoder: UpdateEncoderV1 | UpdateEncoderV2, doc: Doc, targetStateVector: [Int: Int] = [:]) {
    writeClientsStructs(encoder, doc.store, targetStateVector)
    DeleteSet.createFromStructStore(doc.store).encode(encoder)
}

public func encodeStateAsUpdateV2(doc: Doc, encodedTargetStateVector: Data = public func Data(_ [0]), encoder: UpdateEncoderV1 | UpdateEncoderV2 = UpdateEncoderV2()) -> Data{
    let targetStateVector = decodeStateVector(encodedTargetStateVector)
    writeStateAsUpdate(encoder, doc, targetStateVector)
    let updates = [encoder.data]
    // also add the pending updates (if there are any)
    if doc.store.pendingDs {
        updates.push(doc.store.pendingDs)
    }
    if doc.store.pendingStructs {
        updates.push(diffUpdateV2(doc.store.pendingStructs.update, encodedTargetStateVector))
    }
    if updates.length > 1 {
        if encoder.constructor == UpdateEncoderV1 {
            return mergeUpdates(updates.map((update, i) -> i == 0 ? update : convertUpdateFormatV2ToV1(update)))
        } else if encoder.constructor == UpdateEncoderV2 {
            return mergeUpdatesV2(updates)
        }
    }
    return updates[0]
}

public func encodeStateAsUpdate(doc: Doc, encodedTargetStateVector?: Data) -> Data {
    return encodeStateAsUpdateV2(doc, encodedTargetStateVector, UpdateEncoderV1())
}

/**
 * Read state vector from Decoder and return as Map
 *
 * @param {DSDecoderV1 | DSDecoderV2} decoder
 * @return {Map<Int,Int>} Maps `client` to the Int next expected `clock` from that client.
 *
 * @function
 */
public func readStateVector(decoder: DSDecoderV1 | DSDecoderV2) -> [Int: Int] {
    let ss = [:]
    let ssLength = decoder.restDecoder.readUInt()
    public func for(_ var i = 0; i < ssLength; i++) {
        let client = decoder.restDecoder.readUInt()
        let clock = decoder.restDecoder.readUInt()
        ss.set(client, clock)
    }
    return ss
}

public func decodeStateVector(decodedState: Data) -> [Int: Int] {
    return readStateVector(DSDecoderV1(Lib0Decoder(decodedState)))
}

public func writeStateVector(encoder: DSEncoderV1 | DSEncoderV2, sv: [Int: Int]) {
    encoder.restEncoder.writeUInt(sv.size)
    Array.from(sv.entries()).sort((a, b) -> b[0] - a[0]).forEach(([client, clock]) -> {
        encoder.restEncoder.writeUInt(client) // @todo use a special client decoder that is based on mapping
        encoder.restEncoder.writeUInt(clock)
    })
    return encoder
}

public func writeDocumentStateVector(encoder: DSEncoderV1 | DSEncoderV2, doc: Doc) {
    return writeStateVector(encoder, doc.store.getStateVector())
}

public func encodeStateVectorV2(doc: Doc | [Int: Int], encoder: DSEncoderV1 | DSEncoderV2 = public func DSEncoderV2()) -> Data {
    if doc instanceof Map {
        writeStateVector(encoder, doc)
    } else {
        writeDocumentStateVector(encoder, doc)
    }
    return encoder.data
}

public func encodeStateVector(doc: Doc | [Int: Int]) -> Data {
    return encodeStateVectorV2(doc, DSEncoderV1())
}
