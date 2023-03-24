//
//  File.swift
//  
//
//  Created by yuki on 2023/03/23.
//

final public class RefArray<Element> {
    public var value: [Element]
    
    public init(_ value: [Element]) { self.value = value }
    
    public subscript(_ index: Int) -> Element {
        get { self.value[index] }
        set { self.value[index] = newValue }
    }
}

extension RefArray: Sequence {
    public func makeIterator() -> some IteratorProtocol {
        self.value.makeIterator()
    }
}

extension RefArray: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Element
    
    public convenience init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension RefArray: CustomStringConvertible {
    public var description: String { self.value.description }
}

extension RefArray: CustomDebugStringConvertible {
    public var debugDescription: String { self.value.debugDescription }
}

 
