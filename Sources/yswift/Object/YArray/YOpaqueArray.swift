//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

final public class YOpaqueArray: YOpaqueObject {
    public var count: Int {
        return self._prelimContent == nil ? self._length : self._prelimContent!.count
    }
    
    private var _prelimContent: [Any?]? = []

    public override init() {
        super.init()
        self.serchMarkers = []
    }
    
    public convenience init<S: Sequence>(_ contents: S) {
        self.init()
        self.append(contentsOf: contents.map{ $0 })
    }
    
    public func append(contentsOf contents: [Any?]) {
        assert(!contents.contains(where: { $0 is any YWrapperObject }), "You should not put wrapper directory to opaque object.")
        
        if let doc = self.doc {
            doc.transact{ self.listPush(contents, $0) }
        } else {
            self._prelimContent?.append(contentsOf: contents)
        }
    }
    
    public func insert(contentsOf contents: [Any?], at index: Int) {
        assert(!contents.contains(where: { $0 is any YWrapperObject }), "You should not put wrapper directory to opaque object.")
        
        if let doc = self.doc {
            doc.transact{ self.listInsert(contents, at: index, $0) }
        } else {
            self._prelimContent?.insert(contentsOf: contents, at: index)
        }
    }
    
    public func remove(_ index: Int, count: Int = 1) {
        if self.doc != nil {
            self.doc!.transact{ transaction in
                self.listDelete(at: index, count: count, transaction)
            }
        } else {
            self._prelimContent?.removeSubrange(index..<index+count)
        }
    }

    public override func copy() -> YOpaqueArray {
        let array = YOpaqueArray()
        array.insert(contentsOf: self.map{ element in
            element is YOpaqueObject ? (element as! YOpaqueObject).copy() : element
        }, at: 0)
        return array
    }

    public subscript(index: Int) -> Any? {
        return self.listGet(index)
    }
        
    public func slice(_ start: Int = 0, end: Int? = nil) -> [Any?] {
        let end = end ?? self.count
        return self.listSlice(start: start, end: end)
    }
    
    public override func toJSON() -> Any {
        return self.map{ c -> Any? in
            c is YOpaqueObject ? (c as! YOpaqueObject).toJSON() : c 
        }
    }

    override func _integrate(_ y: YDocument, item: YItem?) {
        super._integrate(y, item: item)
        self.insert(contentsOf: self._prelimContent ?? [], at: 0)
        self._prelimContent = nil
    }

    override func _copy() -> YOpaqueArray { return YOpaqueArray() }

    override func _callObserver(_ transaction: YTransaction, _parentSubs: Set<String?>) {
        super._callObserver(transaction, _parentSubs: _parentSubs)
        self.callObservers(transaction: transaction, event: YOpaqueArrayEvent(self, transaction: transaction))
    }

    public override func _write(_ encoder: YUpdateEncoder) {
        encoder.writeTypeRef(YArrayRefID)
    }
}

extension YOpaqueArray: Sequence {
    public typealias Element = Any?
    
    public func makeIterator() -> some IteratorProtocol<Element> {
        self.listCreateIterator()
    }
}

extension YOpaqueArray: CustomStringConvertible {
    public var description: String {
        self.map{ $0 ?? "nil" }.description
    }
}

extension YOpaqueArray {
    public func append(_ content: Any?) {
        self.append(contentsOf: [content])
    }
    
    public func insert(_ content: Any?, at index: Int) {
        self.insert(contentsOf: [content], at: index)
    }
    
    // deprecated
    func toArray() -> [Any?] { Array(self) }
}

func readYArray(_decoder: YUpdateDecoder) -> YOpaqueArray {
    return YOpaqueArray()
}
