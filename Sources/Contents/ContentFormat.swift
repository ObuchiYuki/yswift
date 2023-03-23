//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final public class ContentFormat: Content {
    public var key: String
    public var value: YTextAttributeValue?
    
    init(key: String, value: YTextAttributeValue?) {
        self.key = key
        self.value = value
    }
}

extension ContentFormat {
    public var count: Int { 1 }
    
    public func getContent() -> [Any?] { return [] }

    public func isCountable() -> Bool { return false }

    public func copy() -> ContentFormat { return ContentFormat(key: self.key, value: self.value) }

    public func splice(_ offset: Int) -> ContentFormat { fatalError() }

    public func mergeWith(_ right: Content) -> Bool { return false }

    public func integrate(_ transaction: Transaction, item: Item) {
        (item.parent as! AbstractType)._searchMarker = nil
    }

    public func delete(_ transaction: Transaction) {}
    
    public func gc(_ store: StructStore) {}
    
    public func write(_ encoder: UpdateEncoder, offset: Int) throws {
        encoder.writeKey(self.key)
        try encoder.writeJSON(self.value)
    }

    public func getRef() -> UInt8 { return 6 }
}

extension ContentFormat: CustomStringConvertible {
    public var description: String { "ContentFormat(key: \(key), value: \(value as Any?))" }
}

func readContentFormat(_ decoder: UpdateDecoder) throws -> ContentFormat {
    // TODO: this as? may be wrong
    let key = try decoder.readKey()
    let value = try decoder.readJSON()
    if !(value is YTextAttributeValue?) {
        assertionFailure("'\(value as Any)' (\(type(of: value))) is not YTextAttributeValue")
    }
    return ContentFormat(key: key, value: value as? YTextAttributeValue)
}
