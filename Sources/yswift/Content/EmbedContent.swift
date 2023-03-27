//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final class EmbedContent: Content {
    let embed: Any?
    
    init(_ embed: Any?) { self.embed = embed }
}

extension EmbedContent {
    var count: Int { 1 }
    
    var typeid: UInt8 { 5 }
    
    var isCountable: Bool { true }

    var values: [Any?] { [self.embed] }

    func copy() -> EmbedContent { EmbedContent(self.embed) }

    func splice(_ offset: Int) -> EmbedContent { fatalError() }

    func merge(with right: Content) -> Bool { false }

    func integrate(with item: Item, _ transaction: Transaction) {}
    
    func delete(_ transaction: Transaction) {}
    
    func gc(_ store: StructStore) {}

    func encode(into encoder: YUpdateEncoder, offset: Int) throws { try encoder.writeJSON(self.embed) }
    
    static func decode(from decoder: YUpdateDecoder) throws -> EmbedContent {
        try EmbedContent(decoder.readJSON())
    }
}
