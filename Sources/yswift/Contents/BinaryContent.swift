//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final public class BinaryContent: Content {
    public var content: Data
    
    public init(_ content: Data) {
        self.content = content
    }
}

extension BinaryContent {
    public var count: Int { 1 }
    
    public var typeid: UInt8 { return 3 }

    public func getContent() -> [Any?] { return [self.content] }

    public var isCountable: Bool { true }

    public func copy() -> BinaryContent { return BinaryContent(self.content) }

    public func splice(_ offset: Int) -> BinaryContent { fatalError() }

    public func merge(with right: Content) -> Bool { return false }
    
    public func integrate(with item: Item, _ transaction: Transaction) {}
    
    public func delete(_ transaction: Transaction) {}
    
    public func gc(_ store: StructStore) {}
    
    public func encode(into encoder: UpdateEncoder, offset: Int) { encoder.writeBuf(self.content) }
}

func readContentBinary(_ decoder: UpdateDecoder) throws -> BinaryContent {
    return try BinaryContent(decoder.readBuf())
}
