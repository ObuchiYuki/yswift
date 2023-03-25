//
//  File.swift
//  
//
//  Created by yuki on 2023/03/23.
//

final public class RefArray<Element> {
    public var value: [Element]
    
    public var count: Int { self.value.count }
    
    public init(_ value: [Element]) { self.value = value }
    
    public init(repeating element: Element, count: Int) { self.value = [Element](repeating: element, count: count) }
    
    public subscript(_ index: Int) -> Element {
        get { self.value[index] }
        set { self.value[index] = newValue }
    }
    
    public subscript<R: RangeExpression>(_ range: R) -> RefArray where R.Bound == Int {
        RefArray(self.value[range].map{ $0 })
    }
    
    public func append(_ newElement: Element) {
        self.value.append(newElement)
    }
    
    public func append<S: Sequence>(contentsOf newElements: S) where S.Element == Element {
        self.value.append(contentsOf: newElements)
    }
    
    public func insert(_ newElement: Element, at index: Int) {
        self.value.insert(newElement, at: index)
    }
    
    public func insert<S: Collection>(contentsOf newElements: S, at index: Int) where S.Element == Element {
        self.value.insert(contentsOf: newElements, at: index)
    }
    
    public func remove(at index: Int) -> Element {
        self.value.remove(at: index)
    }
    
    public func popFirst() -> Element? {
        if self.value.isEmpty { return nil }
        return self.value.remove(at: 0)
    }
    
    public func popLast() -> Element? {
        if self.value.isEmpty { return nil }
        return self.value.removeLast()
    }
}

extension RefArray {
    public func map<T>(_ transform: (Element) throws -> T) rethrows -> RefArray<T> {
        try RefArray<T>(self.value.map(transform))
    }
    public func filter(_ condition: (Element) throws -> Bool) rethrows -> RefArray<Element> {
        try RefArray(self.value.filter(condition))
    }
}

extension RefArray: Sequence {
    public func makeIterator() -> some IteratorProtocol<Element> {
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

 
