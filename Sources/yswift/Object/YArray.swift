//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

final class YArrayEvent: YEvent {
    var _transaction: Transaction

    init(_ yarray: YArray, transaction: Transaction) {
        self._transaction = transaction
        super.init(yarray, transaction: transaction)
    }
}

final public class YArray: YObject {
    public var count: Int {
        return self._prelimContent == nil ? self._length : self._prelimContent!.count
    }
    
    private var _prelimContent: [Any?]? = []

    public override init() {
        super.init()
        self.serchMarkers = []
    }
    
    public convenience init<S: Sequence>(_ contents: S) throws {
        self.init()
        try self.append(contentsOf: contents.map{ $0 })
    }
    
    public func append(contentsOf contents: [Any?]) throws {
        if let doc = self.doc {
            try doc.transact{ try self.listPush(contents, $0) }
        } else {
            self._prelimContent?.append(contentsOf: contents)
        }
    }
    
    public func insert(contentsOf contents: [Any?], at index: Int) throws {
        if let doc = self.doc {
            try doc.transact{ try self.listInsert(contents, at: index, $0) }
        } else {
            self._prelimContent?.insert(contentsOf: contents, at: index)
        }
    }
    
    public func remove(_ index: Int, count: Int = 1) throws {
        if self.doc != nil {
            try self.doc!.transact{ transaction in
                try self.listDelete(at: index, count: count, transaction)
            }
        } else {
            self._prelimContent?.removeSubrange(index..<index+count)
        }
    }

    public override func clone() throws -> YArray {
        let array = YArray()
        try array.insert(contentsOf: self.map{ element in
            try element is YObject ? (element as! YObject).clone() : element
        }, at: 0)
        return array
    }

    public subscript(index: Int) -> Any? {
        return self.listGet(index)
    }
        
    public func slice(_ start: Int = 0, end: Int? = nil) -> [Any?] {
        let end = end ?? Int(self.count)
        return self.listSlice(start: start, end: end)
    }
    
    public override func toJSON() -> Any? {
        return self.map{ c in
            c is YObject ? (c as! YObject).toJSON() : c
        }
    }

    override func _integrate(_ y: Doc, item: Item?) throws {
        try super._integrate(y, item: item)
        try self.insert(contentsOf: self._prelimContent ?? [], at: 0)
        self._prelimContent = nil
    }

    override func _copy() -> YArray { return YArray() }

    override func _callObserver(_ transaction: Transaction, _parentSubs: Set<String?>) throws {
        try super._callObserver(transaction, _parentSubs: _parentSubs)
        try self.callObservers(transaction: transaction, event: YArrayEvent(self, transaction: transaction))
    }

    public override func _write(_ encoder: YUpdateEncoder) {
        encoder.writeTypeRef(YArrayRefID)
    }
}

extension YArray: Sequence {
    public typealias Element = Any?
    
    public func makeIterator() -> some IteratorProtocol<Element> {
        self.listCreateIterator()
    }
}

extension YArray {
    public func append(_ content: Any?) throws {
        try self.append(contentsOf: [content])
    }
    
    public func insert(_ content: Any?, at index: Int) throws {
        try self.insert(contentsOf: [content], at: index)
    }
    
    // deprecated
    func toArray() -> [Any?] { Array(self) }
}

func readYArray(_decoder: YUpdateDecoder) -> YArray {
    return YArray()
}
