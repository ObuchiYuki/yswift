//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation
import lib0

public class Snapshot: JSHashable {
    public var ds: DeleteSet
    public var sv: [UInt: UInt]

    public init(_ ds: DeleteSet, sv: [UInt: UInt]) {
        self.ds = ds
        self.sv = sv
    }

    static public func snapshot(_ doc: Doc) -> Snapshot {
        return Snapshot(
            DeleteSet.createFromStructStore(doc.store),
            sv: doc.store.getStateVector()
        )
    }

    static public func empty() -> Snapshot {
        return Snapshot(DeleteSet(), sv: [:])
    }

    public func encodeV2(_ encoder: DSEncoder = DSEncoderV2()) throws -> Data {
        try self.ds.encode(encoder)
        try writeStateVector(encoder: encoder, sv: self.sv.toIntInt())
        return encoder.toData()
    }
    
    public func encode() throws -> Data {
        return try self.encodeV2(DSEncoderV1())
    }
    
    static public func decodeV2(_ buf: Data, decoder: DSDecoder?) throws -> Snapshot {
        let decoder = try decoder ?? DSDecoderV2(Lib0Decoder(data: buf))
        return Snapshot(try DeleteSet.decode(decoder: decoder), sv: try readStateVector(decoder: decoder).toUIntUInt())
    }
    
    static public func decode(_ buf: Data) throws -> Snapshot {
        return try Snapshot.decodeV2(buf, decoder: DSDecoderV1(Lib0Decoder(data: buf)))
    }
   
    public func splitAffectedStructs(_ transaction: Transaction) {
        enum __ { static let marker = UUID() }
        
        var meta = transaction.meta.setIfUndefined(__.marker, Set<AnyHashable>()) as! Set<AnyHashable>
    
        let store = transaction.doc.store
        // check if we already split for this snapshot
        if !meta.contains(self) {
            self.sv.forEach({ client, clock in
                if clock < store.getState(client) {
                    _ = StructStore.getItemCleanStart(transaction, id: ID(client: client, clock: clock))
                }
            })
            self.ds.iterate(transaction, body: {_ in })
            _ = meta.insert(self)
        }
        
        transaction.meta[__.marker] = meta
    }

    
    public func toDoc(_ originDoc: Doc, newDoc: Doc = Doc()) throws -> Doc {
        if originDoc.gc {
            throw YSwiftError.originDocGC
        }
//        let { sv, ds } = self
    
        let encoder = UpdateEncoderV2()
        try originDoc.transact({ transaction in
            var size: UInt = 0
            self.sv.forEach({ clock, _ in
                if clock > 0 {
                    size += 1
                }
            })
            encoder.restEncoder.writeUInt(size)
            // splitting the structs before writing them to the encoder
            for (client, clock) in self.sv {
                if clock == 0 { continue }
                if clock < originDoc.store.getState(client) {
                    _ = StructStore.getItemCleanStart(transaction, id: ID(client: client, clock: clock))
                }
                let structs = originDoc.store.clients[client] ?? []
                let lastStructIndex = try StructStore.findIndexSS(structs: structs, clock: clock - 1)
                // write # encoded structs
                encoder.restEncoder.writeUInt(UInt(lastStructIndex + 1))
                encoder.writeClient(client)
                // first clock written is 0
                encoder.restEncoder.writeUInt(0)
                for i in 0..<lastStructIndex {
                    try structs[i].write(encoder: encoder, offset: 0)
                }
            }
            try ds.encode(encoder)
        })
    
        try applyUpdateV2(ydoc: newDoc, update: encoder.toData(), transactionOrigin: "snapshot")
        return newDoc
    }
    
}


func equalSnapshots(snap1: Snapshot, snap2: Snapshot) -> Bool {
    let ds1 = snap1.ds.clients
    let ds2 = snap2.ds.clients
    let sv1 = snap1.sv
    let sv2 = snap2.sv
    if sv1.count != sv2.count || ds1.count != ds2.count {
        return false
    }
    for (key, value) in sv1 {
        if sv2[key] != value {
            return false
        }
    }
    
    for (client, dsitems1) in ds1  {
        let dsitems2 = ds2[client] ?? []
        if dsitems1.count != dsitems2.count {
            return false
        }
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
