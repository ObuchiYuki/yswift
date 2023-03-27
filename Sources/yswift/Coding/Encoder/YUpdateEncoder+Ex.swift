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
    public func encodeStateAsUpdate(encodedStateVector: Data? = nil, encoder: YUpdateEncoder = YUpdateEncoderV1()) throws -> YUpdate {
        try encoder.encodeStateAsUpdate(doc: self, encodedStateVector: encodedStateVector)
    }
    
    public func encodeStateAsUpdateV2(encodedStateVector: Data? = nil) throws -> YUpdate {
        try self.encodeStateAsUpdate(encodedStateVector: encodedStateVector, encoder: YUpdateEncoderV2())
    }
}

extension YUpdateEncoder {
    func writeStructs(structs: RefArray<YStruct>, client: Int, clock: Int) throws {
        // write first id
        let clock = max(clock, structs[0].id.clock) // make sure the first id exists
        let startNewStructs = try YStructStore.findIndexSS(structs: structs, clock: clock)
            
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
    
    func writeClientsStructs(store: YStructStore, stateVector: [Int: Int]) throws {
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
    
    func writeStructs(from transaction: YTransaction) throws {
        try self.writeClientsStructs(store: transaction.doc.store, stateVector: transaction.beforeState)
    }
    
    func writeStateAsUpdate(doc: Doc, targetStateVector: [Int: Int] = [:]) throws {
        try self.writeClientsStructs(store: doc.store, stateVector: targetStateVector)
        try YDeleteSet.createFromStructStore(doc.store).encode(into: self)
    }

    public func encodeStateAsUpdate(doc: Doc, encodedStateVector: Data? = nil) throws -> YUpdate {
        let encoder = self
        
        let encodedStateVector = encodedStateVector ?? Data([0])
        
        let targetStateVector = try YDeleteSetDecoderV1(encodedStateVector).readStateVector()
        
        try encoder.writeStateAsUpdate(doc: doc, targetStateVector: targetStateVector)
            
        var updates = [encoder.toUpdate()]
        // also add the pending updates (if there are any)
        
        if doc.store.pendingDs != nil {
            updates.append(doc.store.pendingDs!)
        }
        if doc.store.pendingStructs != nil {
            updates.append(try doc.store.pendingStructs!.update.diffV2(to: encodedStateVector))
        }
        
        
        if updates.count > 1 {
            if encoder is YUpdateEncoderV1 {
                return try YUpdate.merged(updates.enumerated().map{ i, update in
                    try i == 0 ? update : update.toV1()
                })
            } else if encoder is YUpdateEncoderV2 {
                return try YUpdate.mergedV2(updates)
            }
        }

        return updates[0]
    }
}

