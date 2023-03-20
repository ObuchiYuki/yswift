//
//  ArrayRef.swift
//  Topica
//
//  Created by yuki on 2019/11/17.
//  Copyright © 2019 yuki. All rights reserved.
//
import Foundation

/// structを参照型にするため
public final class Ref<T> {
    public var value: T

    public init(value: T) {
        self.value = value
    }
}

extension Ref: CustomStringConvertible where T: CustomStringConvertible {
    public var description: String {
        value.description
    }
}

extension Ref: ExpressibleByNilLiteral where T: ExpressibleByNilLiteral {
    public convenience init(nilLiteral: ()) {
        self.init(value: T(nilLiteral: ()))
    }
}

extension Ref: ExpressibleByIntegerLiteral where T: ExpressibleByIntegerLiteral {
    public convenience init(integerLiteral value: T.IntegerLiteralType) {
        self.init(value: T(integerLiteral: value))
    }

    public typealias IntegerLiteralType = T.IntegerLiteralType
}

extension Ref: ExpressibleByFloatLiteral where T: ExpressibleByFloatLiteral {
    public typealias FloatLiteralType = T.FloatLiteralType

    public convenience init(floatLiteral value: T.FloatLiteralType) {
        self.init(value: T.init(floatLiteral: value))
    }
}

extension Ref: ExpressibleByUnicodeScalarLiteral where T: ExpressibleByUnicodeScalarLiteral {
    public typealias UnicodeScalarLiteralType = T.UnicodeScalarLiteralType

    public convenience init(unicodeScalarLiteral value: T.UnicodeScalarLiteralType) {
        self.init(value: T(unicodeScalarLiteral: value))
    }
}

extension Ref: ExpressibleByExtendedGraphemeClusterLiteral where T: ExpressibleByExtendedGraphemeClusterLiteral {
    public typealias ExtendedGraphemeClusterLiteralType = T.ExtendedGraphemeClusterLiteralType

    public convenience init(extendedGraphemeClusterLiteral value: T.ExtendedGraphemeClusterLiteralType) {
        self.init(value: T(extendedGraphemeClusterLiteral: value))
    }
}

extension Ref: ExpressibleByStringLiteral where T: ExpressibleByStringLiteral {
    public typealias StringLiteralType = T.StringLiteralType

    public convenience init(stringLiteral value: T.StringLiteralType) {
        self.init(value: T(stringLiteral: value))
    }
}

extension Ref: ExpressibleByBooleanLiteral where T: ExpressibleByBooleanLiteral {
    public typealias BooleanLiteralType = T.BooleanLiteralType

    public convenience init(booleanLiteral value: T.BooleanLiteralType) {
        self.init(value: T(booleanLiteral: value))
    }
}

extension Ref: Equatable where T: Equatable {
    public static func == (lhs: Ref<T>, rhs: Ref<T>) -> Bool {
        lhs.value == rhs.value
    }
}

extension Ref: Hashable where T: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

extension AdditiveArithmetic {
    public static func += (lhs: inout Self, rhs: Self) { lhs = lhs + rhs }
    public static func -= (lhs: inout Self, rhs: Self) { lhs = lhs - rhs }
}

extension Ref: AdditiveArithmetic where T: AdditiveArithmetic {
    public static func - (lhs: Ref<T>, rhs: Ref<T>) -> Ref<T> {
        Ref(value: lhs.value - rhs.value)
    }
    public static func + (lhs: Ref<T>, rhs: Ref<T>) -> Ref<T> {
        Ref(value: lhs.value + rhs.value)
    }
    public static var zero: Ref<T> {
        Ref(value: T.zero)
    }
}

extension Ref: Numeric where T: Numeric {

    public convenience init?<U: BinaryInteger>(exactly source: U) {
        guard let value = T(exactly: source) else { return nil }

        self.init(value: value)
    }

    public var magnitude: T.Magnitude {
        value.magnitude
    }

    public static func * (lhs: Ref<T>, rhs: Ref<T>) -> Ref<T> {
        Ref(value: lhs.value * rhs.value)
    }

    public static func *= (lhs: inout Ref<T>, rhs: Ref<T>) {
        lhs.value *= rhs.value
    }

    public typealias Magnitude = T.Magnitude
}

extension Ref: Comparable where T: Comparable {
    public static func < (lhs: Ref<T>, rhs: Ref<T>) -> Bool {
        lhs.value < rhs.value
    }
}

//extension Ref: RangeReplaceableCollection where T: RangeReplaceableCollection {
//    public convenience init() {
//        self.init(value: T())
//    }
//    public func append(_ newElement: T.Element) {
//        self.value.append(newElement)
//    }
//}

extension Ref: DataProtocol where T: DataProtocol {
    public typealias Regions = T.Regions

    public var regions: T.Regions { value.regions }
}
extension Ref: MutableCollection where T: MutableCollection {
    public subscript(position: T.Index) -> T.Element { get { return value[position] } set { value[position] = newValue } }
}
extension Ref: Collection where T: Collection {
    public subscript(position: T.Index) -> T.Element {
        value[position]
    }
    
    public var startIndex: T.Index {
        value.startIndex
    }
    
    public var endIndex: T.Index {
        value.endIndex
    }
    
    public var count: Int {
        value.count
    }

    public func index(after i: T.Index) -> T.Index {
        value.index(after: i)
    }

    public typealias Index = T.Index

}

extension Ref: BidirectionalCollection where T: BidirectionalCollection {
    public func index(before i: T.Index) -> T.Index { value.index(before: i) }
    public func index(after i: T.Index) -> T.Index { value.index(after: i) }

    public var startIndex: T.Index { value.startIndex }

    public var endIndex: T.Index { value.endIndex }
}

extension Ref: RandomAccessCollection where T: RandomAccessCollection { }

extension Ref: Sequence where T: Sequence {
    public func makeIterator() -> T.Iterator { value.makeIterator() }

    public typealias Element = T.Element

    public typealias Iterator = T.Iterator

}

extension Ref: Codable where T: Codable {
    public convenience init(from decoder: Decoder) throws {
        self.init(value: try decoder.singleValueContainer().decode(T.self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

extension Ref: Strideable where T: Strideable {
    public func distance(to other: Ref<T>) -> T.Stride {
        value.distance(to: other.value)
    }
    
    public func advanced(by n: T.Stride) -> Ref {
        Ref(value: value.advanced(by: n))
    }
}
