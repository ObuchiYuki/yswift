//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation
import Combine

final public class YMap<Value: YElement> {
    public let opaque: YOpaqueMap
    
    public init(opaque: YOpaqueMap) { self.opaque = opaque }
    
    public convenience init() { self.init(opaque: YOpaqueMap()) }
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
        try self.opaque.setThrowingError(key, value: value)
    }
    
    public func keys() -> some Sequence<String> {
        self.opaque.keys()
    }
    
    public func values() -> some Sequence<Value> {
        self.opaque.values().lazy.map{ Value.decode(from: $0)  }
    }
    
    public func removeValue(forKey key: String) throws {
        try self.opaque.removeValue(forKey: key)
    }
    
    public func contains(_ key: String) -> Bool {
        return self.opaque.contains(key)
    }

    public func removeAll() throws {
        try self.opaque.removeAll()
    }
    
    public func copy() throws -> YMap<Value> {
        try YMap(opaque: self.opaque.clone())
    }
    
    public func toJSON() -> Any {
        self.opaque.toJSON()
    }
}

extension YMap: YElement {
    public func encodeToOpaque() -> Any? { self.opaque }
    public static func decode(from opaque: Any?) -> Self { self.init(opaque: opaque as! YOpaqueMap) }
}

extension YMap: CustomStringConvertible {
    public var description: String { opaque.description }
}

extension YMap: Sequence {
    public typealias Element = (key: String, value: Value)
    
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
