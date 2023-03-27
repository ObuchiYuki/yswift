//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final class BinaryContent: Content {
    var data: Data
    
    init(_ content: Data) { self.data = content }
}

extension BinaryContent {
    var count: Int { 1 }
    
    var typeid: UInt8 { 3 }
    
    var isCountable: Bool { true }

    var values: [Any?] { return [self.data] }

    func copy() -> BinaryContent { return BinaryContent(self.data) }

    func splice(_ offset: Int) -> BinaryContent { fatalError() }

    func merge(with right: Content) -> Bool { return false }
    
    func integrate(with item: YItem, _ transaction: YTransaction) {}
    
    func delete(_ transaction: YTransaction) {}
    
    func gc(_ store: StructStore) {}
    
    func encode(into encoder: YUpdateEncoder, offset: Int) { encoder.writeBuf(self.data) }
    
    static func decode(from decoder: YUpdateDecoder) throws -> BinaryContent {
        try BinaryContent(decoder.readBuf())
    }
}
