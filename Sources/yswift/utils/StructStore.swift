//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation


public class PendingStrcut: CustomStringConvertible {
    public var missing: [Int: Int]
    public var update: Data
    
    init(missing: [Int: Int], update: Data) {
        self.missing = missing
        self.update = update
    }
    
    public var description: String { "PendingStrcut(missing: \(missing), update: \(update.map{ $0 }))" }
}

public class StructStore {
    public var clients: [Int: Ref<[Struct]>] = [:]
    public var pendingStructs: PendingStrcut? = nil 
    public var pendingDs: Data? = nil

    public init() {}

    /** Return the states as a Map<client,clock>. Note that clock refers to the next expected clock id. */
    public func getStateVector() -> [Int: Int] {
        var sm = [Int: Int]()
        self.clients.forEach({ client, structs in
            let struct_ = structs[structs.count - 1]
            sm[client] = struct_.id.clock + struct_.length
        })
        return sm
    }

    public func getState(_ client: Int) -> Int {
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

    public func addStruct(_ struct_: Struct) throws {
        var structs = self.clients[struct_.id.client]
        if structs == nil {
            structs = .init(value: [])
            self.clients[struct_.id.client] = structs
        } else {
            let lastStruct = structs![structs!.count - 1]
            if lastStruct.id.clock + lastStruct.length != struct_.id.clock {
                throw YSwiftError.unexpectedCase
            }
        }
            
        structs!.value.append(struct_)
    }

    /** Expects that id is actually in store. This function throws or is an infinite loop otherwise. */
    public func find(_ id: ID) throws -> Struct {
        let structs = self.clients[id.client]!
        return structs.value[try StructStore.findIndexSS(structs: structs, clock: id.clock)]
    }


    /** Expects that id is actually in store. This function throws or is an infinite loop otherwise. */
    public func getItem(_ id: ID) throws -> Item {
        return try self.find(id) as! Item
    }

    /** Expects that id is actually in store. This function throws or is an infinite loop otherwise. */
    @discardableResult
    static public func getItemCleanStart(_ transaction: Transaction, id: ID) throws -> Item {
        let index = try self.findIndexCleanStart(
            transaction: transaction,
            structs: transaction.doc.store.clients[id.client]!,
            clock: Int(id.clock)
        )

        return transaction.doc.store.clients[id.client]![index] as! Item
    }

    /** Expects that id is actually in store. This function throws or is an infinite loop otherwise. */
    public func getItemCleanEnd(_ transaction: Transaction, id: ID) throws -> Struct {
        let structs = self.clients[id.client]!
        
        let index = try StructStore.findIndexSS(structs: structs, clock: id.clock)
        let struct_ = structs[index]
        if id.clock != struct_.id.clock + struct_.length - 1 && !(struct_ is GC) {            
            structs.value
                .insert((struct_ as! Item).split(transaction, diff: id.clock - struct_.id.clock + 1), at: index + 1)
        }
        return struct_
    }

    /** Replace `item` with `newitem` in store */
    public func replaceStruct(_ struct_: Struct, newStruct: Struct) throws {
        self.clients[struct_.id.client]![
            try StructStore.findIndexSS(structs: self.clients[struct_.id.client]!, clock: struct_.id.clock)
        ] = newStruct
    }

    /** Iterate over a range of structs */
    static public func iterateStructs(transaction: Transaction, structs: Ref<[Struct]>, clockStart: Int, len: Int, f: (Struct) throws -> Void) throws {
        if len == 0 { return }
        let clockEnd = clockStart + len
        var index = try self.findIndexCleanStart(transaction: transaction, structs: structs, clock: clockStart)
        var struct_: Struct
        repeat {
            struct_ = structs.value[index]
            index += 1
            if clockEnd < struct_.id.clock + struct_.length {
                _ = try self.findIndexCleanStart(transaction: transaction, structs: structs, clock: clockEnd)
            }
            try f(struct_)
        } while (index < structs.count && structs[index].id.clock < clockEnd)
    }


    /** Perform a binary search on a sorted array */
    public static func findIndexSS(structs: Ref<[Struct]>, clock: Int) throws -> Int {
        var left = 0
        var right = structs.count - 1
        var mid = structs[right]
        var midclock = mid.id.clock
        if midclock == clock {
            return right
        }
        // @todo does it even make sense to pivot the search?
        // If a good split misses, it might actually increase the time to find the correct item.
        // Currently, the only advantage is that search with pivoting might find the item on the first try.
        var midindex = (clock / (midclock + mid.length - 1)) * right
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
            midindex = (left + right) / 2
        }
        // Always check state before looking for a struct in StructStore
        // Therefore the case of not finding a struct is unexpected
        throw YSwiftError.unexpectedCase
    }

    public static func findIndexCleanStart(transaction: Transaction, structs: Ref<[Struct]>, clock: Int) throws -> Int {
        let index = try StructStore.findIndexSS(structs: structs, clock: clock)
        let struct_ = structs[index]
        if struct_.id.clock < clock && struct_ is Item {
            structs.value
                .insert(((struct_ as! Item).split(transaction, diff: clock - (struct_ as! Item).id.clock)), at: index + 1)
            return index + 1
        }
        return index
    }
}
