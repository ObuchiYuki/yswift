//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation

final public class YArray<Element: YElement>: YConcreteObject {
    public let opaque: YOpaqueArray
    
    public init(opaque: YOpaqueArray) { self.opaque = opaque }
    
    public convenience init() { self.init(opaque: YOpaqueArray()) }
}

extension YArray {
    public var count: Int { opaque.count }
    
    public func remove(at index: Int, count: Int = 1) throws {
        try opaque.remove(index)
    }
    
    public func copy() throws -> YArray<Element> {
        try YArray(opaque: self.opaque.clone())
    }
    
    public func toJSON() -> Any {
        self.opaque.toJSON()
    }
}

extension YArray: CustomStringConvertible {
    public var description: String { opaque.description }
}
