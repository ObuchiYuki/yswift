//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final public class ContentBinary: Content {
    public var content: Data
    
    public init(_ content: Data) {
        self.content = content
    }

    public func getLength() -> UInt { return 1 }

    public func getContent() -> [Any] { return [self.content] }

    public func isCountable() -> Bool { return true }

    public func copy() -> ContentBinary { return ContentBinary(self.content) }

    public func splice(_ offset: UInt) -> ContentBinary { fatalError() }

    public func mergeWith(_ right: Content) -> Bool { return false }
    
    public func integrate(_ transaction: Transaction, item: Item) {}
    
    public func delete(_ transaction: Transaction) {}
    
    public func gc(_ store: StructStore) {}
    
    public func write(_ encoder: UpdateEncoder, offset: UInt) { encoder.writeBuf(self.content) }

    public func getRef() -> UInt8 { return 3 }
}

func readContentBinary(_ decoder: UpdateDecoder) throws -> ContentBinary {
    return try ContentBinary(decoder.readBuf())
}
