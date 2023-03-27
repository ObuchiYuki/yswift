//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation
import Combine

extension YArray where Element: YCodable {
    public convenience init<S: Sequence>(_ contents: S) throws where S.Element == Element {
        self.init(opaque: try YOpaqueArray(contents.lazy.map{ try $0.encode() }))
    }
    
    public func append(_ content: Element) throws {
        try self.opaque.append(content.encode())
    }
    public func append<S: Sequence>(contentsOf contents: S) throws where S.Element == Element {
        try self.opaque.append(contentsOf: contents.map{ try $0.encode() })
    }
    
    public func insert(_ content: Element, at index: Int) throws {
        try self.opaque.insert(content.encode(), at: index)
    }
    public func insert<S: Sequence>(contentsOf contents: S, at index: Int) throws where S.Element == Element {
        try self.opaque.insert(contents.map{ try $0.encode() }, at: index)
    }

    public subscript(index: Int) -> Element {
        get throws { try Element.decode(from: self.opaque[index] as! NSDictionary) }
    }
    public subscript<R: _RangeExpression>(range: R) -> [Element] {
        get throws {
            let range = range.relative(to: self.count)
            return try self.opaque.slice(range.lowerBound, end: range.upperBound)
                .map{ try Element.decode(from: $0 as! NSDictionary) }
        }
    }
}

extension YArray where Element: YCodable {
    public func sequence() throws -> some Sequence<Element> {
        try self.opaque.lazy.map{ try Element.decode(from: $0 as! NSDictionary)  }
    }
    public func forEach(_ transform: (Element) throws -> Void) throws {
        try sequence().forEach(transform)
    }
    public func map<T>(_ transform: (Element) throws -> T) throws -> [T] {
        try sequence().map(transform)
    }
    public func filter(_ condition: (Element) throws -> Bool) throws -> [Element] {
        try sequence().filter(condition)
    }
    
    public func toArray() throws -> [Element] {
        try self.sequence().map{ $0 }
    }
}
