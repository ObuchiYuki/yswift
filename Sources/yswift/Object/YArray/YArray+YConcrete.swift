//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation

extension YArray where Element: YConcreteObject {
    public convenience init<S: Sequence>(_ contents: S) throws where S.Element == Element {
        self.init(opaque: try YOpaqueArray(contents.lazy.map{ $0.opaque }))
    }
    
    public func append(_ content: Element) throws {
        try self.opaque.append(content.opaque)
    }
    public func append<S: Sequence>(contentsOf contents: S) throws where S.Element == Element {
        try self.opaque.append(contentsOf: contents.map{ $0.opaque })
    }
    
    public func insert(_ content: Element, at index: Int) throws {
        try self.opaque.insert(content.opaque, at: index)
    }
    public func insert<S: Sequence>(contentsOf contents: S, at index: Int) throws where S.Element == Element {
        try self.opaque.insert(contents.map{ $0.opaque }, at: index)
    }

    public subscript(index: Int) -> Element {
        return Element(opaque: self.opaque[index] as! Element.Opaque)
    }
    public subscript<R: _RangeExpression>(range: R) -> [Element] {
        let range = range.relative(to: self.count)
        return self.opaque.slice(range.lowerBound, end: range.upperBound).map{ Element(opaque: $0 as! Element.Opaque) }
    }
}

extension YArray where Element: YConcreteObject {
    public func sequence() -> some Sequence<Element> {
        self.opaque.lazy.map{ Element(opaque: $0 as! Element.Opaque)  }
    }
    public func forEach(_ transform: (Element) throws -> Void) rethrows {
        try sequence().forEach(transform)
    }
    public func map<T>(_ transform: (Element) throws -> T) rethrows -> [T] {
        try sequence().map(transform)
    }
    public func filter(_ condition: (Element) throws -> Bool) rethrows -> [Element] {
        try sequence().filter(condition)
    }

    public func toArray() -> [Element] {
        self.sequence().map{ $0 }
    }
}
