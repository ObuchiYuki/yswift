//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

protocol Content: AnyObject {
    var count: Int { get }
    
    var typeid: UInt8 { get }
    
    var isCountable: Bool { get }
    
    var values: [Any?] { get }
    
    func copy() -> Self
    
    func splice(_ offset: Int) -> Self

    func merge(with right: any Content) -> Bool

    func integrate(with item: YItem, _ transaction: YTransaction) throws -> Void

    func delete(_ transaction: YTransaction) -> Void

    func gc(_ store: StructStore) throws -> Void

    func encode(into encoder: YUpdateEncoder, offset: Int) throws -> Void
    
    static func decode(from decoder: YUpdateDecoder) throws -> Self
}

func decodeContent(from decoder: YUpdateDecoder, info: UInt8) throws -> any Content {
    return try contentDecoders_[Int(info & 0b0001_1111)](decoder)
}

/** A lookup map for reading Item content. */
fileprivate let contentDecoders_: [(YUpdateDecoder) throws -> any Content] = [
    {_ in throw YSwiftError.unexpectedCase }, // GC is not ItemContent
    DeletedContent.decode(from:), // 1
    JSONContent.decode(from:), // 2
    BinaryContent.decode(from:), // 3
    StringContent.decode(from:), // 4
    EmbedContent.decode(from:), // 5
    FormatContent.decode(from:), // 6
    TypeContent.decode(from:), // 7
    AnyContent.decode(from:), // 8
    DocumentContent.decode(from:), // 9
    {_ in throw YSwiftError.unexpectedCase }, // 10 - Skip is not ItemContent
]
