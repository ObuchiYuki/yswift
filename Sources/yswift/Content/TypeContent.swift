//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

final class TypeContent: Content {
    var type: YObject
    
    init(_ type: YObject) { self.type = type }
}

extension TypeContent {
    var count: Int { 1 }
    
    var typeid: UInt8 { 7 }
    
    var isCountable: Bool { true }

    var values: [Any?] { [self.type] }

    func copy() -> TypeContent { TypeContent(self.type._copy()) }

    func splice(_ offset: Int) -> TypeContent { fatalError() }

    func merge(with right: Content) -> Bool { false }

    func integrate(with item: YItem, _ transaction: Transaction) throws {
        try self.type._integrate(transaction.doc, item: item)
    }

    func delete(_ transaction: Transaction) {
        var item = self.type._start
        while let uitem = item {
            if !uitem.deleted {
                uitem.delete(transaction)
            } else {
                transaction._mergeStructs.value.append(uitem)
            }
            item = uitem.right as? YItem
        }
        for (_, item) in self.type.storage {
            if !item.deleted {
                item.delete(transaction)
            } else {
                transaction._mergeStructs.value.append(item)
            }
        }
        transaction.changed.removeValue(forKey: self.type)
    }

    func gc(_ store: StructStore) throws {
        var item = self.type._start
        while let uitem = item {
            try uitem.gc(store, parentGC: true)
            item = uitem.right as? YItem
        }
        
        self.type._start = nil
        for (_, item) in self.type.storage {
            var item: YItem? = item
            while let uitem = item {
                try uitem.gc(store, parentGC: true)
                item = uitem.left as? YItem
            }
        }
        self.type.storage = [:]
    }

    func encode(into encoder: YUpdateEncoder, offset: Int) {
        self.type._write(encoder)
    }
    
    static func decode(from decoder: YUpdateDecoder) throws -> TypeContent {
        return try TypeContent(
            typeRefs[Int(decoder.readTypeRef())](decoder)
        )
    }
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
