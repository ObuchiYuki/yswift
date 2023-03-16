//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final public class ContentFormat: Content {
    public var key: String
    public var value: Any
    
    init(key: String, value: Any) {
        self.key = key
        self.value = value
    }

    public func getLength() -> UInt { return 1 }
    
    public func getContent() -> [Any] { return [] }

    public func isCountable() -> Bool { return false }

    public func copy() -> ContentFormat { return ContentFormat(key: self.key, value: self.value) }

    public func splice(_ offset: UInt) -> ContentFormat { fatalError() }

    public func mergeWith(_ right: Content) -> Bool { return false }

    public func integrate(_ transaction: Transaction, item: Item) {
        (item.parent as! AbstractType)._searchMarker = nil
    }

    public func delete(_ transaction: Transaction) {}
    
    public func gc(_ store: StructStore) {}
    
    public func write(_ encoder: UpdateEncoder, offset: UInt) throws {
        encoder.writeKey(self.key)
        try encoder.writeJSON(self.value)
    }

    public func getRef() -> UInt8 { return 6 }
}

func readContentFormat(_ decoder: UpdateDecoder) throws -> ContentFormat {
    return try ContentFormat(key: decoder.readKey(), value: decoder.readJSON())
}
