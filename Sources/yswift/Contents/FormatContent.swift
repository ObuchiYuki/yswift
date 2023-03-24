//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final public class FormatContent: Content {
    public var key: String
    public var value: YTextAttributeValue?
    
    init(key: String, value: YTextAttributeValue?) {
        self.key = key
        self.value = value
    }
}

extension FormatContent {
    public var count: Int { 1 }
    
    public func getContent() -> [Any?] { return [] }

    public var isCountable: Bool { false }

    public func copy() -> FormatContent { return FormatContent(key: self.key, value: self.value) }

    public func splice(_ offset: Int) -> FormatContent { fatalError() }

    public func merge(with right: Content) -> Bool { return false }

    public func integrate(with item: Item, _ transaction: Transaction) {
        (item.parent as! AbstractType)._searchMarker = nil
    }

    public func delete(_ transaction: Transaction) {}
    
    public func gc(_ store: StructStore) {}
    
    public func encode(into encoder: UpdateEncoder, offset: Int) throws {
        encoder.writeKey(self.key)
        try encoder.writeJSON(self.value)
    }

    public var typeid: UInt8 { return 6 }
}

extension FormatContent: CustomStringConvertible {
    public var description: String { "ContentFormat(key: \(key), value: \(value as Any?))" }
}

func readContentFormat(_ decoder: UpdateDecoder) throws -> FormatContent {
    // TODO: this as? may be wrong
    let key = try decoder.readKey()
    let value = try decoder.readJSON()
    if !(value is YTextAttributeValue?) {
        assertionFailure("'\(value as Any)' (\(type(of: value))) is not YTextAttributeValue")
    }
    return FormatContent(key: key, value: value as? YTextAttributeValue)
}
