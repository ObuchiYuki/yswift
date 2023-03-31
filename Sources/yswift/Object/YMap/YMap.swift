//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation
import Combine

final public class YMap<Value: YElement>: YWrapperObject {
    public let opaque: YOpaqueMap
    
    public init(opaque: YOpaqueMap) { self.opaque = opaque }
    
    public convenience init() { self.init(opaque: YOpaqueMap()) }
    
    public convenience init(_ dictionary: [String: Value]) { self.init(opaque: YOpaqueMap(dictionary)) }
}

extension YMap {
    public var count: Int { self.opaque.count }
    
    public var isEmpty: Bool { self.opaque.isEmpty }
    
    public subscript(key: String) -> Value? {
        get {
            guard let value = self.opaque[key] else { return nil }
            return Value.decode(from: value)
        }
        set { self.opaque[key] = newValue?.encodeToOpaque() }
    }

    public func setThrowingError(_ key: String, value: Value?) throws {
        self.opaque.set(key, value: value)
    }
    
    public func keys() -> some Sequence<String> {
        self.opaque.keys()
    }
    
    public func values() -> some Sequence<Value> {
        self.opaque.values().lazy.map{ Value.decode(from: $0)  }
    }
    
    public func removeValue(forKey key: String) throws {
        self.opaque.removeValue(forKey: key)
    }
    
    public func contains(_ key: String) -> Bool {
        return self.opaque.contains(key)
    }

    public func removeAll() throws {
        self.opaque.removeAll()
    }
    
    public func copy() throws -> YMap<Value> {
        YMap(opaque: self.opaque.copy())
    }
    
    public func toJSON() -> Any {
        self.opaque.toJSON()
    }
    
    public func toDictionary() -> [String: Value] {
        Dictionary(uniqueKeysWithValues: self)
    }
}

extension YMap: YElement {
    public func encodeToOpaque() -> Any? { self.opaque }
    public static func decode(from opaque: Any?) -> Self { self.init(opaque: opaque as! YOpaqueMap) }
}

extension YMap: ExpressibleByDictionaryLiteral {
    public convenience init(dictionaryLiteral elements: (String, Value)...) {
        self.init(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension YMap: CustomStringConvertible {
    public var description: String { self.toDictionary().description }
}

extension YMap: Equatable where Value: Equatable {
    public static func == (lhs: YMap<Value>, rhs: YMap<Value>) -> Bool {
        lhs.toDictionary() == rhs.toDictionary()
    }
}

extension YMap: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(toDictionary())
    }
}

extension YMap: Sequence {
    public typealias Element = (String, Value)
    
    public func makeIterator() -> some IteratorProtocol<Element> {
        self.opaque.lazy.map{ (key: $0, value: Value.decode(from: $1)) }.makeIterator()
    }
}

extension YMap {
    public var publisher: some Combine.Publisher<Void, Never> {
        self.opaque._eventHandler.publisher.map{_ in () }
    }
    
    public var deepPublisher: some Combine.Publisher<Void, Never> {
        self.opaque._deepEventHandler.publisher.map{_ in () }
    }
}
