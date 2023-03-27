//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation

extension YMap where Value: YConcreteObject {
    public subscript(key: String) -> Value? {
        get {
            guard let value = self.opaque[key] else { return nil }
            return Value(opaque: value as! Value.Opaque)
        }
        set { self.opaque[key] = newValue?.opaque }
    }

    public func setThrowingError(_ key: String, value: Value?) throws {
        try self.opaque.setThrowingError(key, value: value)
    }
}

extension YMap where Value: YConcreteObject {
    public func values() -> some Sequence<Value> {
        self.opaque.values().lazy.map{ Value(opaque: $0 as! Value.Opaque)  }
    }
    public func sequence() -> some Sequence<(key: String, value: Value)> {
        self.opaque.lazy.map{ (key: $0, value: Value(opaque: $1 as! Value.Opaque)) }
    }
}
