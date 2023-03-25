//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final class FormatContent: Content {
    var key: String
    var value: YTextAttributeValue?
    
    init(key: String, value: YTextAttributeValue?) {
        self.key = key
        self.value = value
    }
}

extension FormatContent {
    var count: Int { 1 }
    
    var typeid: UInt8 { return 6 }
    
    var isCountable: Bool { false }
    
    var values: [Any?] { [] }

    func copy() -> FormatContent { return FormatContent(key: self.key, value: self.value) }

    func splice(_ offset: Int) -> FormatContent { fatalError() }

    func merge(with right: Content) -> Bool { false }

    func integrate(with item: Item, _ transaction: Transaction) {
        item.parent?.object?.serchMarkers = nil
    }

    func delete(_ transaction: Transaction) {}
    
    func gc(_ store: StructStore) {}
    
    func encode(into encoder: UpdateEncoder, offset: Int) throws {
        encoder.writeKey(self.key)
        try encoder.writeJSON(self.value)
    }

    static func decode(from decoder: UpdateDecoder) throws -> FormatContent {
        // TODO: this as? may be wrong
        let key = try decoder.readKey()
        let value = try decoder.readJSON()
        if !(value is YTextAttributeValue?) {
            assertionFailure("'\(value as Any)' (\(type(of: value))) is not YTextAttributeValue")
        }
        return FormatContent(key: key, value: value as? YTextAttributeValue)
    }
}

extension FormatContent: CustomStringConvertible {
    var description: String { "ContentFormat(key: \(key), value: \(value as Any?))" }
}
