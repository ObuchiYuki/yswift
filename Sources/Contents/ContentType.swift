//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

final public class ContentType: Content {
    public var type: AbstractType
    
    public init(_ type: AbstractType) { self.type = type }
}

extension ContentType {
    public var count: Int { 1 }

    public func getContent() -> [Any?] { return [self.type] }

    public func isCountable() -> Bool { return true }

    public func copy() -> ContentType { return ContentType(self.type._copy()) }

    public func splice(_ offset: Int) -> ContentType { fatalError() }

    public func mergeWith(_ right: Content) -> Bool { return false }

    public func integrate(_ transaction: Transaction, item: Item) throws {
        try self.type._integrate(transaction.doc, item: item)
    }

    public func delete(_ transaction: Transaction) {
        var item = self.type._start
        while (item != nil) {
            if !item!.deleted {
                item!.delete(transaction)
            } else {
                transaction._mergeStructs.value.append(item!)
            }
            item = (item!.right as? Item)
        }
        self.type._map.forEach({ _, item in
            if !item.deleted {
                item.delete(transaction)
            } else {
                // same as above
                transaction._mergeStructs.value.append(item)
            }
        })
        transaction.changed.removeValue(forKey: self.type)
    }

    public func gc(_ store: StructStore) throws {
        var item = self.type._start
        while (item != nil) {
            try item!.gc(store, parentGCd: true)
            item = (item!.right as? Item)
        }
        self.type._start = nil
        try self.type._map.forEach({ _, item in
            var item: Item? = item
            while (item != nil) {
                try item!.gc(store, parentGCd: true)
                item = (item!.left as? Item)
            }
        })
        self.type._map = [:]
    }

    public func write(_ encoder: UpdateEncoder, offset: Int) {
        self.type._write(encoder)
    }

    public func getRef() -> UInt8 { return 7 }
}

private let typeRefs = [
    readYArray,
    readYMap,
    readYText,
//    readYXmlElement,
//    readYXmlFragment,
//    readYXmlHook,
//    readYXmlText
]
let YArrayRefID: UInt8 = 0
let YMapRefID: UInt8 = 1
let YTextRefID: UInt8 = 2
//let YXmlElementRefID: UInt8 = 3
//let YXmlFragmentRefID: UInt8 = 4
//let YXmlHookRefID: UInt8 = 5
//let YXmlTextRefID: UInt8 = 6

func readContentType(_ decoder: UpdateDecoder) throws -> ContentType {
    return try ContentType(
        typeRefs[Int(decoder.readTypeRef())](decoder)
    )
}
