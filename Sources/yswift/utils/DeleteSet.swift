//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

public class DeleteItem {
    public let clock: UInt
    public var len: UInt
    
    public init(clock: UInt, len: UInt) {
        self.clock = clock
        self.len = len
    }

    static public func findIndex(_ dis: [DeleteItem], clock: UInt) -> Int? {
        var left = 0
        var right = dis.count - 1
        
        while (left <= right) {
            let midindex = (left+right) / 2
            let mid = dis[midindex]
            let midclock = mid.clock
            if midclock <= clock {
                if clock < midclock + mid.len {
                    return midindex
                }
                left = midindex + 1
            } else {
                right = midindex - 1
            }
        }
        return nil
    }
}

public class DeleteSet {
    public var clients: [UInt: [DeleteItem]] = [:]

    public func iterate(_ transaction: Transaction, body: (GC_or_Item) -> Void) throws {
        
        return try self.clients.forEach{ clientid, deletes in
            for i in 0..<deletes.count {
                let del = deletes[i]
                try StructStore.iterateStructs(
                    transaction: transaction,
                    structs: &transaction.doc.store.clients[clientid]!,
                    clockStart: del.clock, len: del.len, f: body
                )
            }
        }
    }

    public func isDeleted(_ id: ID) -> Bool {
        let dis = self.clients[id.client]
        return dis != nil && DeleteItem.findIndex(dis!, clock: id.clock) != nil
    }

    public func sortAndMerge() {
        self.clients.forEach{ _, _dels in
            var dels = _dels.sorted(by: { a, b in a.clock < b.clock })
            var i: Int = 1, j: Int = 1
                
            while i < dels.count {
                let left = dels[j - 1]
                let right = dels[i]
                if left.clock + left.len >= right.clock {
                    left.len = max(left.len, right.clock + right.len - left.clock)
                } else {
                    if j < i { dels[j] = right }
                    j += 1
                }
                i += 1
            }
            dels = dels[..<j].map{ $0 }
        }
    }

    public func add(client: UInt, clock: UInt, length: UInt) {
        if self.clients[client] == nil {
            self.clients[client] = []
        }
        
        self.clients[client]!.append(DeleteItem(clock: clock, len: length))
    }
    
    public func encode(_ encoder: any DSEncoder) throws {
        encoder.restEncoder.writeUInt(UInt(self.clients.count))
    
        // Ensure that the delete set is written in a deterministic order
        try self.clients
            .sorted(by: { $0.key < $1.key })
            .forEach({ client, dsitems in
                encoder.resetDsCurVal()
                encoder.restEncoder.writeUInt(client)
                let len = dsitems.count
                encoder.restEncoder.writeUInt(UInt(len))
                for i in 0..<len {
                    let item = dsitems[i]
                    encoder.writeDsClock(item.clock)
                    try encoder.writeDsLen(item.len)
                }
            })
    }

    public func tryGCDeleteSet(_ store: StructStore, gcFilter: (Item) -> Bool) throws {
        for (client, deleteItems) in self.clients {
            let structs = store.clients[client]!
            
            for di in (0..<deleteItems.count).reversed() {
                let deleteItem = deleteItems[di]
                let endDeleteItemClock = deleteItem.clock + deleteItem.len
                
                var si = try StructStore.findIndexSS(structs: structs, clock: deleteItem.clock)
                var struct_ = structs[si];
                
                while si < structs.count && struct_.id.clock < endDeleteItemClock {
                    let struct__ = structs[si]
                    if deleteItem.clock + deleteItem.len <= struct__.id.clock {
                        break
                    }
                    if type(of: struct__) == Item.self && struct__.deleted && !(struct__ as! Item).keep && gcFilter(struct__ as! Item) {
                        try (struct__ as! Item).gc(store, parentGCd: false)
                    }
                    
                    si += 1
                    struct_ = structs[si]
                }
            }
        }
    }

    public func tryMerge(_ store: StructStore) throws {
        try self.clients.forEach({ client, deleteItems in
            let structs = store.clients[client]!
            
            for di in (0..<deleteItems.count).reversed() {
                let deleteItem = deleteItems[di]
                // start with merging the item next to the last deleted item
                let mostRightIndexToCheck = min(
                    structs.count - 1,
                    try 1 + StructStore.findIndexSS(structs: structs, clock: deleteItem.clock + deleteItem.len - 1)
                )
                var si = mostRightIndexToCheck, struct_ = structs[si];
                
                while si > 0 && struct_.id.clock >= deleteItem.clock {
                    Struct.tryMerge(withLeft: structs, pos: si)
                    si -= 1
                    struct_ = structs[si]
                }
            }
        })
    }

    public func tryGC(_ store: StructStore, gcFilter: (Item) -> Bool) throws {
        try self.tryGCDeleteSet(store, gcFilter: gcFilter)
        try self.tryMerge(store)
    }
    
    public static func mergeAll(_ dss: [DeleteSet]) -> DeleteSet {
        let merged = DeleteSet()
        
        for dssI in 0..<dss.count {
            dss[dssI].clients.forEachMutating({ client, delsLeft in
                if merged.clients[client] == nil {
                    for i in dssI+1..<dss.count {
                        delsLeft += dss[i].clients[client] ?? []
                    }
                    merged.clients[client] = delsLeft
                }
            })
        }
        merged.sortAndMerge()
        return merged
    }

    public static func decode(decoder: DSDecoder) throws -> DeleteSet {
        let ds = DeleteSet()
        let numClients = try decoder.restDecoder.readUInt()
        
        for _ in 0..<numClients {
            decoder.resetDsCurVal()
            let client = try decoder.restDecoder.readUInt()
            let IntOfDeletes = try decoder.restDecoder.readUInt()
            if IntOfDeletes > 0 {
                if ds.clients[client] == nil { ds.clients[client] = [] }
                
                for _ in 0..<IntOfDeletes {
                    ds.clients[client]!.append(DeleteItem(
                        clock: try decoder.readDsClock(),
                        len: try decoder.readDsLen()
                    ))
                }
            }
        }
        return ds
    }
    
    static public func createFromStructStore(_ ss: StructStore) -> DeleteSet {
        let ds = DeleteSet()
        
        for (client, structs) in ss.clients {
            var dsitems: [DeleteItem] = []
            
            var i = 0; while i < structs.count {
                let struct_ = structs[i]
                if struct_.deleted {
                    let clock = struct_.id.clock
                    var len = struct_.length
                    if i + 1 < structs.count {
                        var next = structs[i + 1]
                        
                        while i + 1 < structs.count && next.deleted {
                            len += next.length
                            i += 1
                            next = structs[i + 1]
                        }
                    }
                    
                    dsitems.append(DeleteItem(clock: clock, len: len))
                }
                i += 1
            }
            if dsitems.count > 0 {
                ds.clients[client] = dsitems
            }
        }
        
        return ds
    }

    static public func decodeAndApply(_ decoder: DSDecoder, transaction: Transaction, store: StructStore) throws -> Data? {
        let unappliedDS = DeleteSet()
        let numClients = try decoder.restDecoder.readUInt()
        
        for _ in 0..<numClients {
            decoder.resetDsCurVal()
            let client = try decoder.restDecoder.readUInt()
            let IntOfDeletes = try decoder.restDecoder.readUInt()
            var structs = store.clients[client] ?? []
            let state = store.getState(client)
            
            for _ in 0..<IntOfDeletes {
                let clock = try decoder.readDsClock()
                let clockEnd = try clock + decoder.readDsLen()
                if clock < state {
                    if state < clockEnd {
                        unappliedDS.add(client: client, clock: state, length: clockEnd - state)
                    }
                    var index = try StructStore.findIndexSS(structs: structs, clock: clock)
                    var struct_: Item = structs[index] as! Item
                    // split the first item if necessary
                    if !struct_.deleted && struct_.id.clock < clock {
                        structs.insert(struct_.split(transaction, diff: clock - struct_.id.clock), at: index + 1)
                        index += 1 // increase we now want to use the next struct
                    }
                    while (index < structs.count) {
                        struct_ = structs[index] as! Item
                        index += 1
                        if struct_.id.clock < clockEnd {
                            if !struct_.deleted {
                                if clockEnd < struct_.id.clock + struct_.length {
                                    structs.insert(struct_.split(transaction, diff: clockEnd - struct_.id.clock), at: index)
                                }
                                struct_.delete(transaction)
                            }
                        } else {
                            break
                        }
                    }
                } else {
                    unappliedDS.add(client: client, clock: clock, length: clockEnd - clock)
                }
            }
        }
        if unappliedDS.clients.count > 0 {
            let ds = UpdateEncoderV2()
            ds.restEncoder.writeUInt(0) // encode 0 structs
            try unappliedDS.encode(ds)
            return ds.toData()
        }
        return nil
    }

}
