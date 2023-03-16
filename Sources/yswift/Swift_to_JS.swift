//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

extension Array where Element == UInt8 {
    var uint16Array: [UInt16] {
        
    }
}

final public class JSString {
    public let data: [UInt16]
    
    public var count: Int { data.count }
    
    public var swiftString: String {
        
    }
    
    public init() { self.data = [] }
    public init(_ data: [UInt16]) { self.data = data }
    
    public func charCodeAt(_ index: UInt) -> UInt16 { data[Int(index)] }
    
    public static func + (lhs: JSString, rhs: JSString) -> JSString {
        return JSString(lhs.data + rhs.data)
    }
    
    public func slice(_ start: UInt, _ end: UInt? = nil) -> JSString {
        if let end = end {
            return JSString(data[Int(start)..<Int(end)].map{ $0 })
        } else {
            return JSString(data[Int(start)...].map{ $0 })
        }
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
    
    public mutating func setIfUndefined(_ key: Key, _ make: @autoclosure () -> Value) -> Value {
        if let value = self[key] { return value }
        let newValue = make()
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

public func generateNewClientID() -> UInt {
    return UInt(UInt32.random(in: UInt32.min...UInt32.max))
}
