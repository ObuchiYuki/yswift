//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation

extension YArray where Element: YPrimitive {
    public convenience init<S: Sequence>(_ contents: S) throws where S.Element == Element {
        self.init(opaque: try YOpaqueArray(contents))
    }
    
    public func append(_ content: Element) throws {
        try self.opaque.append(content)
    }
    public func append<S: Sequence>(contentsOf contents: S) throws where S.Element == Element {
        try self.opaque.append(contentsOf: contents.map{ $0 })
    }
    
    public func insert(_ content: Any?, at index: Int) throws {
        try self.opaque.insert(content, at: index)
    }
    public func insert<S: Sequence>(contentsOf contents: S, at index: Int) throws {
        try self.opaque.insert(contents.map{ $0 }, at: index)
    }

    public subscript(index: Int) -> Element {
        self.opaque[index] as! Element
    }
    public subscript<R: _RangeExpression>(range: R) -> [Element] {
        let range = range.relative(to: self.count)
        return self.opaque.slice(range.lowerBound, end: range.upperBound).map{ $0 as! Element }
    }
}

extension YArray where Element: YPrimitive {
    public func sequence() -> some Sequence<Element> {
        self.opaque.lazy.map{ $0 as! Element }
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

extension YArray: Equatable where Element: YPrimitive {
    public static func == (lhs: YArray<Element>, rhs: YArray<Element>) -> Bool {
        lhs.sequence().map{ $0 } == rhs.sequence().map{ $0 }
    }
}
