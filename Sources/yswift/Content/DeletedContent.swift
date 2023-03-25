//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final class DeletedContent {
    var length: Int
    
    init(_ len: Int) { self.length = len }
}

extension DeletedContent: Content {
    var count: Int { self.length }
    
    var typeid: UInt8 { 1 }
    
    var isCountable: Bool { false }

    var values: [Any?] { return [] }

    func copy() -> DeletedContent { return DeletedContent(self.length) }

    func splice(_ offset: Int) -> DeletedContent {
        let right = DeletedContent(self.length - offset)
        self.length = offset
        return right
    }

    func merge(with right: Content) -> Bool {
        self.length += (right as! DeletedContent).length
        return true
    }

    func integrate(with item: Item, _ transaction: Transaction) {
        transaction.deleteSet.add(client: item.id.client, clock: item.id.clock, length: self.length)
        item.deleted = true
    }

    func delete(_ transaction: Transaction) {}
    
    func gc(_ store: StructStore) {}
    
    func encode(into encoder: UpdateEncoder, offset: Int) { encoder.writeLen(self.length - offset) }

    
    static func decode(from decoder: UpdateDecoder) throws -> DeletedContent {
        try DeletedContent(decoder.readLen())
    }
}
