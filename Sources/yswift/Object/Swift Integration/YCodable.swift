//
//  File.swift
//  
//
//  Created by yuki on 2023/04/07.
//

import Foundation

private let encoder = DictionaryEncoder()
private let decoder = DictionaryDecoder()

extension YElement where Self: Encodable {
    public func persistenceObject() -> Any? { try! encoder.encode(self) }
}

extension YElement where Self: Decodable {
    public static func fromPersistence(_ opaque: Any?) -> Self {
        try! decoder.decode(Self.self, from: opaque)
    }
}

