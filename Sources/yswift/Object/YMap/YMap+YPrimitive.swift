//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation

extension YMap where Value: YPrimitive {
    public subscript(key: String) -> Value? {
        get {
            guard let value = self.opaque[key] else { return nil }
            return (value as! Value)
        }
        set { self.opaque[key] = newValue }
    }

    public func setThrowingError(_ key: String, value: Value?) throws {
        try self.opaque.setThrowingError(key, value: value)
    }
}

extension YMap where Value: YPrimitive {
    public func values() -> some Sequence<Value> {
        self.opaque.values().lazy.map{ $0 as! Value }
    }
    public func sequence() -> some Sequence<(key: String, value: Value)> {
        self.opaque.lazy.map{ (key: $0, value: $1 as! Value) }
    }
}
