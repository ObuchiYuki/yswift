//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation
import Combine

final public class YArray<Element: YElement> {
    public let opaque: YOpaqueArray
    
    public var count: Int { self.opaque.count }
    
    public var isEmpty: Bool { self.opaque.count == 0 }
    
    
    public init(opaque: YOpaqueArray) { self.opaque = opaque }
    
    public convenience init() { self.init(opaque: YOpaqueArray()) }
    
    public convenience init<S: Sequence>(_ contents: S) throws where S.Element == Element {
        self.init(opaque: try YOpaqueArray(contents.lazy.map{ $0.encodeToOpaque() }))
    }
    
    
    public func append(_ content: Element) throws {
        try self.opaque.append(content.encodeToOpaque())
    }
    public func append<S: Sequence>(contentsOf contents: S) throws where S.Element == Element {
        try self.opaque.append(contentsOf: contents.map{ $0.encodeToOpaque() })
    }
    
    public func insert(_ content: Element, at index: Int) throws {
        try self.opaque.insert(content.encodeToOpaque(), at: index)
    }
    public func insert<S: Sequence>(contentsOf contents: S, at index: Int) throws where S.Element == Element {
        try self.opaque.insert(contents.map{ $0.encodeToOpaque() }, at: index)
    }

    public func remove(at index: Int, count: Int = 1) throws {
        try opaque.remove(index)
    }
    
    public func copy() throws -> YArray<Element> {
        try YArray(opaque: self.opaque.copy())
    }
    
    public func toJSON() -> Any { self.opaque.toJSON() }
    
    public func toArray() -> [Element] { Array(self) }
    
    public subscript(index: Int) -> Element {
        return Element.decode(from: self.opaque[index])
    }
    public subscript<R: _RangeExpression>(range: R) -> [Element] {
        let range = range.relative(to: self.count)
        return self.opaque.slice(range.lowerBound, end: range.upperBound).map{ Element.decode(from: $0) }
    }
}

extension YArray: Equatable where Element: Equatable {
    public static func == (lhs: YArray<Element>, rhs: YArray<Element>) -> Bool {
        lhs.toArray() == rhs.toArray()
    }
}

extension YArray: Hashable where Element: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.toArray())
    }
}

extension YArray: YElement {
    public func encodeToOpaque() -> Any? { self.opaque }
    public static func decode(from opaque: Any?) -> Self { self.init(opaque: opaque as! YOpaqueArray) }
}

extension YArray: CustomStringConvertible {
    public var description: String { self.toArray().description }
}

extension YArray: Sequence {
    public func makeIterator() -> some IteratorProtocol<Element> {
        self.opaque.lazy.map{ Element.decode(from: $0) }.makeIterator()
    }
}

extension YArray: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Element
    
    public convenience init(arrayLiteral elements: Element...) {
        try! self.init(elements)
    }
}

extension YArray {
    public var publisher: some Combine.Publisher<YEvent, Never> {
        self.opaque._eventHandler.publisher.map{ event, _ in event }
    }
    
    public var deepPublisher: some Combine.Publisher<[YEvent], Never> {
        self.opaque._deepEventHandler.publisher.map{ event, _ in event }
    }
}
