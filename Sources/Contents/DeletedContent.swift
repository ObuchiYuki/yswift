//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final public class DeletedContent {
    public var len: Int
    
    public init(_ len: Int) { self.len = len }
}

extension DeletedContent: Content {
    public var count: Int { self.len }

    public func getContent() -> [Any?] { return [] }

    public func isCountable() -> Bool { return false }

    public func copy() -> DeletedContent { return DeletedContent(self.len) }

    public func splice(_ offset: Int) -> DeletedContent {
        let right = DeletedContent(self.len - offset)
        self.len = offset
        return right
    }

    public func mergeWith(_ right: Content) -> Bool {
        self.len += (right as! DeletedContent).len
        return true
    }

    public func integrate(_ transaction: Transaction, item: Item) {
        transaction.deleteSet.add(client: item.id.client, clock: item.id.clock, length: self.len)
        item.markDeleted()
    }

    public func delete(_ transaction: Transaction) {}
    
    public func gc(_ store: StructStore) {}
    
    public func write(_ encoder: UpdateEncoder, offset: Int) { encoder.writeLen(self.len - offset) }

    public func getRef() -> UInt8 { return 1 }
}

func readContentDeleted(_ decoder: UpdateDecoder) throws -> DeletedContent {
    return try DeletedContent(decoder.readLen())
}
