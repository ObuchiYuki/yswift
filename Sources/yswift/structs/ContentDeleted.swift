//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final public class ContentDeleted: Content {
    public var len: UInt
    
    public init(_ len: UInt) { self.len = len }

    public func getLength() -> UInt { return self.len }

    public func getContent() -> [Any] { return [] }

    public func isCountable() -> Bool { return false }

    public func copy() -> ContentDeleted { return ContentDeleted(self.len) }

    public func splice(_ offset: UInt) -> ContentDeleted {
        let right = ContentDeleted(self.len - offset)
        self.len = offset
        return right
    }

    public func mergeWith(_ right: Content) -> Bool {
        self.len += (right as! ContentDeleted).len
        return true
    }

    public func integrate(_ transaction: Transaction, item: Item) {
        transaction.deleteSet.add(client: item.id.client, clock: item.id.clock, length: self.len)
        item.markDeleted()
    }

    public func delete(_ transaction: Transaction) {}
    
    public func gc(_ store: StructStore) {}
    
    public func write(_ encoder: UpdateEncoder, offset: UInt) { encoder.writeLen(self.len - offset) }

    public func getRef() -> UInt8 { return 1 }
}

func readContentDeleted(_ decoder: UpdateDecoder) throws -> ContentDeleted {
    return try ContentDeleted(decoder.readLen())
}
