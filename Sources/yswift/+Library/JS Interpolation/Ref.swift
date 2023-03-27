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
    
    public func copy() -> Ref<T> { Ref(value: value) }
}

extension Ref: CustomStringConvertible where T: CustomStringConvertible {
    public var description: String {
        value.description
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

extension Ref: Strideable where T: Strideable {
    public func distance(to other: Ref<T>) -> T.Stride {
        value.distance(to: other.value)
    }
    
    public func advanced(by n: T.Stride) -> Ref {
        Ref(value: value.advanced(by: n))
    }
}

extension Ref: Comparable where T: Comparable {
    public static func < (lhs: Ref<T>, rhs: Ref<T>) -> Bool {
        lhs.value < rhs.value
    }
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
