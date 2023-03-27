//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation
import Combine

final public class YArray<Element: YElement>: YConcreteObject {
    public let opaque: YOpaqueArray
    
    public init(opaque: YOpaqueArray) { self.opaque = opaque }
    
    public convenience init() { self.init(opaque: YOpaqueArray()) }
}

extension YArray {
    public var count: Int { self.opaque.count }
    
    public var isEmpty: Bool { self.opaque.count == 0 }
    
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

extension YArray {
    public var publisher: some Combine.Publisher<Void, Never> {
        self.opaque._eventHandler.publisher.map{_ in () }
    }
    
    public var deepPublisher: some Combine.Publisher<Void, Never> {
        self.opaque._deepEventHandler.publisher.map{_ in () }
    }
}

extension YArray: CustomStringConvertible {
    public var description: String { opaque.description }
}
