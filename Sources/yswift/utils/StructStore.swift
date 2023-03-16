//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation


public struct PendingStrcut {
    public var missing: [Int: Int]
    public var update: Data
}

public class StructStore {
    public var clients: [UInt: [GC_or_Item]] = [:]
    public var pendingStructs: PendingStrcut? = nil
    public var pendingDs: Data? = nil

    public init() {}

    /** Return the states as a Map<client,clock>. Note that clock refers to the next expected clock id. */
    public func getStateVector() -> [UInt: UInt] {
        var sm = [UInt: UInt]()
        self.clients.forEach({ client, structs in
            let struct_ = structs[structs.count - 1]
            sm[client] = struct_.id.clock + struct_.length
        })
        return sm
    }

    public func getState(_ client: UInt) -> UInt {
        let structs = self.clients[client]
        if structs == nil {
            return 0
        }
        let lastStruct = structs![structs!.count - 1]
        return lastStruct.id.clock + lastStruct.length
    }

    public func integretyCheck() throws {
        try self.clients.forEach{ _, structs in
            for i in 1..<structs.count {
                let l = structs[i - 1]
                let r = structs[i]
                if l.id.clock + l.length != r.id.clock {
                    throw YSwiftError.integretyCheckFail
                }
            }
        }
    }

    public func addStruct(_ struct_: GC_or_Item) throws {
        if self.clients[struct_.id.client] == nil {
            self.clients[struct_.id.client] = []
        } else {
            let lastStruct = self.clients[struct_.id.client]!.last!
            if lastStruct.id.clock + lastStruct.length != struct_.id.clock {
                throw YSwiftError.unexpectedCase
            }
        }
        self.clients[struct_.id.client]!.append(struct_)
    }

    /** Expects that id is actually in store. This function throws or is an infinite loop otherwise. */
    public func find(_ id: ID) -> GC_or_Item {
        let structs = self.clients[id.client]!
        return structs[StructStore.findIndexSS(structs, id.clock)]
    }


    /** Expects that id is actually in store. This function throws or is an infinite loop otherwise. */
    public func getItem(_ id: ID) -> Item {
        return self.find(id) as! Item
    }

    /** Expects that id is actually in store. This function throws or is an infinite loop otherwise. */
    static public func getItemCleanStart(_ transaction: Transaction, id: ID) -> Item {
        let structs = transaction.doc.store.clients[id.client] as! [Item]
        return structs[self.findIndexCleanStart(transaction, structs, id.clock)]
    }

    /** Expects that id is actually in store. This function throws or is an infinite loop otherwise. */
    public func getItemCleanEnd(_ transaction: Transaction, id: ID) -> Item {
        let structs = self.clients[id.client] as! [Item]
        let index = StructStore.findIndexSS(structs, id.clock)
        let struct_ = structs[index]
        if id.clock != struct_.id.clock + struct_.length - 1 && struct_.constructor != GC {
            structs.insert(struct_.split(transaction, id.clock - struct_.id.clock + 1), at: index + 1)
        }
        return struct_
    }

    /** Replace `item` with `newitem` in store */
    public func replaceStruct(_ struct_: GC_or_Item, newStruct: GC_or_Item) {
        self.clients[struct_.id.client]![
            StructStore.findIndexSS(self.clients[struct_.id.client]!, struct_.id.clock)
        ] = newStruct
    }

    /** Iterate over a range of structs */
    static public func iterateStructs(transaction: Transaction, structs: [GC_or_Item], clockStart: UInt, len: UInt, f: (GC_or_Item) -> Void) {
        if len == 0 { return }
        let clockEnd = clockStart + len
        var index = self.findIndexCleanStart(transaction, structs, clockStart)
        var struct_: GC_or_Item!
        repeat {
            struct_ = structs[index]
            index += 1
            if clockEnd < struct_.id.clock + struct_.length {
                self.findIndexCleanStart(transaction, structs, clockEnd)
            }
            f(struct_)
        } while (index < structs.count && structs[index].id.clock < clockEnd)
    }


    /** Perform a binary search on a sorted array */
    public static func findIndexSS(structs: [GC_or_Item], clock: UInt) throws -> Int {
        var left = 0
        var right = structs.length - 1
        var mid = structs[right]
        var midclock = mid.id.clock
        if midclock == clock {
            return right
        }
        // @todo does it even make sense to pivot the search?
        // If a good split misses, it might actually increase the time to find the correct item.
        // Currently, the only advantage is that search with pivoting might find the item on the first try.
        var midindex = Int(floor((clock / (midclock + mid.length - 1)) * right)) // pivoting the search
        while (left <= right) {
            mid = structs[midindex]
            midclock = mid.id.clock
            if midclock <= clock {
                if clock < midclock + mid.length {
                    return midindex
                }
                left = midindex + 1
            } else {
                right = midindex - 1
            }
            midindex = Int(floor((left + right) / 2))
        }
        // Always check state before looking for a struct in StructStore
        // Therefore the case of not finding a struct is unexpected
        throw YSwiftError.unexpectedCase
    }

    public static func findIndexCleanStart(transaction: Transaction, structs: [GC_or_Item], clock: Int) {
        let index = StructStore.findIndexSS(structs, clock)
        let struct_ = structs[index]
        if struct_.id.clock < clock && struct_ is Item {
            structs.splice(index + 1, 0, (struct_ as! Item).split(transaction, clock - (struct_ as! Item).id.clock))
            return index + 1
        }
        return index
    }
}
