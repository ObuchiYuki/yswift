//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

public protocol GC_or_Item {}
extension Item: GC_or_Item{}

public class DeleteItem {
    public let clock: UInt
    public var len: UInt
    
    public init(clock: UInt, len: UInt) {
        self.clock = clock
        self.len = len
    }

    static public func findIndex(_ dis: Ref<[DeleteItem]>, clock: UInt) -> Int? {
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
    public var clients: [UInt: Ref<[DeleteItem]>] = [:]

    public func iterate(_ transaction: Transaction, body: (GC_or_Item) -> Void) {
        
        return self.clients.forEach{ clientid, deletes in
            let structs = transaction.doc.store.clients[clientid]!
            
            for i in 0..<deletes.count {
                let del = deletes[i]
                StructStore.iterateStructs(transaction, structs, del.clock, del.len, body)
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
        (
            self.clients[client] ?? Ref<[DeleteItem]>([]) => {
                self.clients[client] = $0
            }
        )
        .append(DeleteItem(clock: clock, len: length))
    }
    
    public func encode(_ encoder: any DSEncoder) {
        encoder.restEncoder.writeUInt(UInt(self.clients.count))
    
        // Ensure that the delete set is written in a deterministic order
        self.clients
            .sorted(by: { $0.key < $1.key })
            .forEach({ client, dsitems in
                encoder.resetDsCurVal()
                encoder.restEncoder.writeUInt(client)
                let len = dsitems.count
                encoder.restEncoder.writeUInt(UInt(len))
                for i in 0..<len {
                    let item = dsitems[i]
                    encoder.writeDsClock(item.clock)
                    encoder.writeDsLen(item.len)
                }
            })
    }

    public func tryGCDeleteSet(_ store: StructStore, gcFilter: (Item) -> Bool) {
        for (client, deleteItems) in self.clients {
            let structs = store.clients[client] as! GC_or_Item[]
            
            for di in (0..<deleteItems.count).reversed() {
                let deleteItem = deleteItems[di]
                let endDeleteItemClock = deleteItem.clock + deleteItem.len
                
                var si = StructStore.findIndexSS(structs, deleteItem.clock), struct_ = structs[si];
                
                while si < structs.length && struct_.id.clock < endDeleteItemClock {
                    let struct_ = structs[si]
                    if deleteItem.clock + deleteItem.len <= struct_.id.clock {
                        break
                    }
                    if type(of: struct_) == Item.self && struct_.deleted && !struct_.keep && gcFilter(struct_) {
                        struct_.gc(store, false)
                    }
                    
                    si += 1
                    struct_ = structs[si]
                }
            }
        }
    }

    public func tryMerge(_ store: StructStore) {
        self.clients.forEach({ client, deleteItems in
            let structs = store.clients[client] as! GC_or_Item[]
            
            for di in (0..<deleteItems.count).reversed() {
                let deleteItem = deleteItems[di]
                // start with merging the item next to the last deleted item
                let mostRightIndexToCheck = min(
                    structs.length - 1,
                    1 + StructStore.findIndexSS(structs, deleteItem.clock + deleteItem.len - 1)
                )
                var si = mostRightIndexToCheck, struct_ = structs[si];
                
                while si > 0 && struct_.id.clock >= deleteItem.clock {
                    Struct.tryMergeWithLeft(structs, si)
                    si -= 1
                    struct_ = structs[si]
                }
            }
        })
    }

    public func tryGC(_ store: StructStore, gcFilter: (Item) -> Bool) {
        self.tryGCDeleteSet(store, gcFilter)
        self.tryMerge(store)
    }
    
    public static func mergeAll(_ dss: [DeleteSet]) -> DeleteSet {
        let merged = DeleteSet()
        
        for dssI in 0..<dss.count {
            dss[dssI].clients.forEach({ client, delsLeft in
                if merged.clients[client] == nil {
                    var dels: [DeleteItem] = delsLeft.value
                    for i in dssI+1..<dss.count {
                        dels += dss[i].clients[client] ?? Ref([])
                    }
                    merged.clients[client] = Ref(dels)
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
                let dsField = ds.clients[client] ?? Ref<[DeleteItem]>([]) => {
                    ds.clients[client] = $0
                }
                
                for _ in 0..<IntOfDeletes {
                    dsField.append(DeleteItem(
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
            let dsitems: [DeleteItem] = []
            for i in 0..<structs.count {
                let struct_ = structs[i]
                if struct_.deleted {
                    let clock = struct_.id.clock
                    var len = struct_.length
                    if i + 1 < structs.length {
                        var next = structs[i + 1]
                        
                        while i + 1 < structs.length && next.deleted {
                            len += next.length
                            i += 1
                            next = structs[i + 1]
                        }
                    }
                    
                    dsitems.append(DeleteItem(clock: clock, len: len))
                }
            }
            if dsitems.length > 0 {
                ds.clients[client] = dsitems
            }
        }
        
        return ds
    }

    static public func decodeAndApply(_ decoder: DSDecoder, transaction: Transaction, store: StructStore) -> Data? {
        let unappliedDS = DeleteSet()
        let numClients = decoder.restDecoder.readUInt()
        
        for _ in 0..<numClients {
            decoder.resetDsCurVal()
            let client = decoder.restDecoder.readUInt()
            let IntOfDeletes = decoder.restDecoder.readUInt()
            let structs = store.clients.get(client) || []
            let state = store.getState(client)
            
            for _ in 0..<IntOfDeletes {
                let clock = decoder.readDsClock()
                let clockEnd = clock + decoder.readDsLen()
                if clock < state {
                    if state < clockEnd {
                        unappliedDS.add(client, state, clockEnd - state)
                    }
                    var index = StructStore.findIndexSS(structs, clock)
                    var struct_: Item = structs[index] as! Item
                    // split the first item if necessary
                    if !struct_.deleted && struct_.id.clock < clock {
                        structs.splice(index + 1, 0, struct_.split(transaction, clock - struct_.id.clock))
                        index++ // increase we now want to use the next struct
                    }
                    while (index < structs.length) {
                        struct_ = structs[index++] as Item
                        if struct_.id.clock < clockEnd {
                            if !struct_.deleted {
                                if clockEnd < struct_.id.clock + struct_.length {
                                    structs.splice(index, 0, struct_.split(transaction, clockEnd - struct_.id.clock))
                                }
                                struct_.delete(transaction)
                            }
                        } else {
                            break
                        }
                    }
                } else {
                    unappliedDS.add(client, clock, clockEnd - clock)
                }
            }
        }
        if unappliedDS.clients.size > 0 {
            let ds = UpdateEncoderV2()
            ds.restEncoder.writeUInt(0) // encode 0 structs
            unappliedDS.encode(ds)
            return ds.data
        }
        return nil
    }

}
