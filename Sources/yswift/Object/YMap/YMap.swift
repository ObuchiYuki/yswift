//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation
import Combine

final public class YMap<Value: YElement>: YConcreteObject {
    public let opaque: YOpaqueMap
    
    public init(opaque: YOpaqueMap) { self.opaque = opaque }
    
    public convenience init() { self.init(opaque: YOpaqueMap()) }
}

extension YMap {
    public var count: Int { self.opaque.count }
    
    public var isEmpty: Bool { self.opaque.isEmpty }
    
    public func keys() -> some Sequence<String> { self.opaque.keys() }
    
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

extension YMap {
    public var publisher: some Combine.Publisher<Void, Never> {
        self.opaque._eventHandler.publisher.map{_ in () }
    }
    
    public var deepPublisher: some Combine.Publisher<Void, Never> {
        self.opaque._deepEventHandler.publisher.map{_ in () }
    }
}

extension YMap: CustomStringConvertible {
    public var description: String { opaque.description }
}
