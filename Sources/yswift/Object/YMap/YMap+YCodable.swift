//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation

extension YMap where Value: YCodable {
    public subscript(key: String) -> Value? {
        get { try! getThrowingError(key) }
        set { try! setThrowingError(key, value: newValue) }
    }

    public func getThrowingError(_ key: String) throws -> Value? {
        guard let value = self.opaque[key] else { return nil }
        return try! Value.decode(from: value as! NSDictionary)
    }
    
    public func setThrowingError(_ key: String, value: Value?) throws {
        try self.opaque.setThrowingError(key, value: value?.encode())
    }
}

extension YMap where Value: YCodable {
    public func values() throws -> some Sequence<Value> {
        try self.opaque.values().lazy.map{ try Value.decode(from: $0 as! NSDictionary)  }
    }
    public func sequence() throws -> some Sequence<(key: String, value: Value)> {
        try self.opaque.lazy.map{ try (key: $0, value: Value.decode(from: $1 as! NSDictionary)) }
    }
}
