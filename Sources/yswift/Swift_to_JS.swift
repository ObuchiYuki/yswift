//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation
import Promise

// not complete copy of ===
func jsStrictEqual(_ a: Any?, _ b: Any?) -> Bool {
    if a == nil && b == nil {
        return true
    }
    // this may check JS object and array content
    if let a = a as? AnyHashable, let b = b as? AnyHashable {
        return a == b
    }
    return false
}

func removeDualOptional<T>(_ value: T??) -> T? {
    switch value {
    case .none: return nil
    case .some(let value):
        switch value {
        case .none: return nil
        case .some(let value): return value
        }
    }
}

extension NSRange {
    public init(from: Int, to: Int) {
        self.init(location: from, length: to-from)
    }
    
    public init(_ range: Range<Int>) {
        self.init(from: range.lowerBound, to: range.upperBound)
    }
}

public protocol JSHashable: AnyObject, Hashable, Equatable {}

extension JSHashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}


extension Dictionary {
    public mutating func forEachMutating(_ block: (Key, inout Value) -> Void) {
        for key in self.keys {
            block(key, &self[key]!)
        }
    }
    
    public mutating func setIfUndefined(_ key: Key, _ make: @autoclosure () throws -> Value) rethrows -> Value {
        if let value = self[key] { return value }
        let newValue = try make()
        self[key] = newValue
        return newValue
    }
}

extension Array {
    public func jsReduce(_ body: (Element, Element) -> Element) -> Element {
        if self.isEmpty { fatalError() }
        if self.count == 1 { return self[0] }
        
        return self[1...].reduce(self[0], body)
    }
}

public func generateDocGuid() -> String {
    #if DEBUG // to remove randomness
    enum __ { static var cliendID: UInt = 0 }
    if NSClassFromString("XCTest") != nil {
        __.cliendID += 1
        return String(__.cliendID)
    }
    #endif
    return UUID().uuidString
}

public func generateNewClientID() -> UInt {
    #if DEBUG // to remove randomness
    enum __ { static var cliendID: UInt = 0 }
    if NSClassFromString("XCTest") != nil {
        __.cliendID += 1
        return __.cliendID
    }
    #endif
    return UInt(UInt32.random(in: UInt32.min...UInt32.max))
}

public func equalFlat(a: [String: Any?], b: [String: Any?]) -> Bool {
    // TODO: may be wrong
    if let a = a as? [String: AnyHashable?], let b = b as? [String: AnyHashable?], a == b {
        return true
    }
    
//    if a.keys.count != b.keys.count { return false }
//
//    for (key, value) in a {
//        if (!(value != nil || b[key] != nil) && b[key] == value) {
//            return false
//        }
//    }
    return true
}

public func equalAttributes(_ a: Any?, _ b: Any?) -> Bool {
    if (a == nil && b == nil) { return true }
    if !(a is [String: Any]), let a = a as? AnyHashable, let b = b as? AnyHashable {
        return a == b
    }
    
    if a is [String: Any]? && b is [String: Any]? {
        return a != nil && b != nil && equalFlat(a: a as! [String: Any?], b: b as! [String: Any?])
    }
    
    return false
}
