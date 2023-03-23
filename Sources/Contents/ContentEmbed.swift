//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final public class ContentEmbed: Content {
    public let embed: Any?
    
    public init(_ embed: Any?) { self.embed = embed }
}

extension ContentEmbed {
    public var count: Int { 1 }

    public func getContent() -> [Any?] { return [self.embed] }

    public func isCountable() -> Bool { return true }

    public func copy() -> ContentEmbed { return ContentEmbed(self.embed) }

    public func splice(_ offset: Int) -> ContentEmbed { fatalError() }

    public func mergeWith(_ right: Content) -> Bool { return false }

    public func integrate(_ transaction: Transaction, item: Item) {}
    
    public func delete(_ transaction: Transaction) {}
    
    public func gc(_ store: StructStore) {}

    public func write(_ encoder: UpdateEncoder, offset: Int) throws { try encoder.writeJSON(self.embed) }

    public func getRef() -> UInt8 { return 5 }
}

func readContentEmbed(_ decoder: UpdateDecoder) throws -> ContentEmbed {
    return try ContentEmbed(decoder.readJSON())
}
