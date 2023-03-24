//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final public class EmbedContent: Content {
    public let embed: Any?
    
    public init(_ embed: Any?) { self.embed = embed }
}

extension EmbedContent {
    public var count: Int { 1 }

    public func getContent() -> [Any?] { return [self.embed] }

    public var isCountable: Bool { true }

    public func copy() -> EmbedContent { return EmbedContent(self.embed) }

    public func splice(_ offset: Int) -> EmbedContent { fatalError() }

    public func merge(with right: Content) -> Bool { return false }

    public func integrate(with item: Item, _ transaction: Transaction) {}
    
    public func delete(_ transaction: Transaction) {}
    
    public func gc(_ store: StructStore) {}

    public func encode(into encoder: UpdateEncoder, offset: Int) throws { try encoder.writeJSON(self.embed) }

    public var typeid: UInt8 { return 5 }
}

func readContentEmbed(_ decoder: UpdateDecoder) throws -> EmbedContent {
    return try EmbedContent(decoder.readJSON())
}
