//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final public class YSnapshot: JSHashable {
    public var deleteSet: YDeleteSet
    public var stateVectors: [Int: Int]

    public init(deleteSet: YDeleteSet, stateVectors: [Int: Int]) {
        self.deleteSet =  deleteSet
        self.stateVectors = stateVectors
    }
    
    public convenience init() {
        self.init(deleteSet: YDeleteSet(), stateVectors: [:])
    }
    
    public convenience init(doc: YDocument) {
        self.init(
            deleteSet: YDeleteSet.createFromStructStore(doc.store),
            stateVectors: doc.store.getStateVector()
        )
    }
   
    public func splitAffectedStructs(_ transaction: YTransaction) throws {
        enum __ { static let marker = UUID() }
        
        var meta = transaction.meta.setIfUndefined(__.marker, Set<AnyHashable>()) as! Set<AnyHashable>
    
        let store = transaction.doc.store
        // check if we already split for this snapshot
        if !meta.contains(self) {
            for (client, clock) in self.stateVectors where clock < store.getState(client) {
                try YStructStore.getItemCleanStart(transaction, id: YID(client: client, clock: clock))
            }
            try self.deleteSet.iterate(transaction, body: {_ in })
            _ = meta.insert(self)
        }
        
        transaction.meta[__.marker] = meta
    }

    
    public func toDoc(_ originDoc: YDocument) throws -> YDocument {
        let newDoc = YDocument()
        if originDoc.gc { throw YSwiftError.originDocGC }
        
        let encoder = YUpdateEncoderV2()
        
        try originDoc.transact{ transaction in
            let size = self.stateVectors.lazy.filter{ $0.key > 0 }.count
            
            encoder.restEncoder.writeUInt(UInt(size))

            for (client, clock) in self.stateVectors where clock != 0 {
                if clock < originDoc.store.getState(client) {
                    try YStructStore.getItemCleanStart(transaction, id: YID(client: client, clock: clock))
                }
                let structs = originDoc.store.clients[client] ?? []
                let lastStructIndex = try YStructStore.findIndexSS(structs: structs, clock: clock - 1)
                // write # encoded structs
                encoder.restEncoder.writeUInt(UInt(lastStructIndex + 1))
                encoder.writeClient(client)
                // first clock written is 0
                encoder.restEncoder.writeUInt(0)
                for i in 0..<lastStructIndex {
                    try structs[i].encode(into: encoder, offset: 0)
                }
            }
            try deleteSet.encode(into: encoder)
            
        }
    
        try newDoc.applyUpdateV2(encoder.toUpdate(), transactionOrigin: "snapshot")
        
        return newDoc
    }
}

// Coding
extension YSnapshot {
    public func encodeV2(_ encoder: YDeleteSetEncoder = YDeleteSetEncoderV2()) throws -> Data {
        try self.deleteSet.encode(into: encoder)
        try encoder.writeStateVector(from: self.stateVectors)
        return encoder.toData()
    }
    
    public func encode() throws -> Data {
        return try self.encodeV2(YDeleteSetEncoderV1())
    }
    
    static public func decodeV2(_ buf: Data, decoder: YDeleteSetDecoder? = nil) throws -> YSnapshot {
        let decoder = try decoder ?? YDeleteSetDecoderV2(LZDecoder(buf))
        return YSnapshot(
            deleteSet: try YDeleteSet.decode(decoder: decoder),
            stateVectors: try decoder.readStateVector()
        )
    }
    
    static public func decode(_ buf: Data) throws -> YSnapshot {
        return try YSnapshot.decodeV2(buf, decoder: YDeleteSetDecoderV1(LZDecoder(buf)))
    }
}

extension YSnapshot: Equatable {
    public static func == (lhs: YSnapshot, rhs: YSnapshot) -> Bool {
        let ds1 = lhs.deleteSet.clients
        let ds2 = rhs.deleteSet.clients
        let sv1 = lhs.stateVectors
        let sv2 = rhs.stateVectors
        
        if sv1.count != sv2.count || ds1.count != ds2.count { return false }
        
        for (key, value) in sv1 where sv2[key] != value { return false }
        
        for (client, dsitems1) in ds1 {
            let dsitems2 = ds2[client] ?? []
            if dsitems1.count != dsitems2.count { return false }
            
            for i in 0..<dsitems1.count {
                let dsitem1 = dsitems1[i]
                let dsitem2 = dsitems2[i]
                if dsitem1.clock != dsitem2.clock || dsitem1.len != dsitem2.len {
                    return false
                }
            }
        }
        
        return true
    }
}
