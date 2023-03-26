//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

final public class RefDictionary<Key: Hashable, Value> {
    public typealias Element = (key: Key, value: Value)

    public var value: [Key: Value]
    
    public var count: Int { value.count }

    public var isEmpty: Bool { value.isEmpty }

    public init() { self.value = [:] }
    
    public init(_ value: [Key: Value]) { self.value = value }
    
    public subscript(key: Key) -> Value? {
        get { self.value[key] } set { self.value[key] = newValue }
    }
    
    public func copy() -> RefDictionary<Key, Value> {
        RefDictionary(self.value)
    }
}

extension RefDictionary: ExpressibleByDictionaryLiteral {
    public convenience init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension RefDictionary: Sequence {
    public func makeIterator() -> some IteratorProtocol<Element> {
        self.value.makeIterator()
    }
}
