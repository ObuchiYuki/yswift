//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

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
