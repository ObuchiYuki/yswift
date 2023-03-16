//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

public class YArrayEvent: YEvent {
    public var _transaction: Transaction

    public init(_ yarray: YArray, transaction: Transaction) {
        self._transaction = transaction
        super.init(yarray, transaction: transaction)
    }
}

/** A shared Array implementation. */
public class YArray: AbstractType {
    public var _prelimContent: [Any]? = []

    public override init() {
        super.init()
        self._searchMarker = []
    }

    /** Construct a YArray containing the specified items. */
    static func from(items: [Any]) throws -> YArray {
        let a = YArray()
        try a.push(items)
        return a
    }

    /**
     * Integrate this type into the Yjs instance.
     *
     * * Save this struct in the os
     * * This type is sent to other client
     * * Observer functions are fired
     */
    public override func _integrate(_ y: Doc, item: Item?) throws {
        try super._integrate(y, item: item)
        try self.insert(0, content: self._prelimContent ?? [])
        self._prelimContent = nil
    }

    public override func _copy() -> YArray { return YArray() }

    public override func clone() throws -> YArray {
        let array = YArray()
        try array.insert(0, content: self.toArray().map{ element in
            try element is AbstractType ? (element as! AbstractType).clone() : element
        })
        return array
    }

    public var length: UInt {
        return self._prelimContent == nil ? self._length : UInt(self._prelimContent!.count)
    }

    /**
     * Creates YArrayEvent and calls observers.
     *
     * @param {Transaction} transaction
     * @param {Set<nil|String>} parentSubs Keys changed on this type. `nil` if list was modified.
     */
    public override func _callObserver(_ transaction: Transaction, _parentSubs: Set<String?>) {
        super._callObserver(transaction, _parentSubs: _parentSubs)
        self.callObservers(transaction: transaction, event: YArrayEvent(self, transaction: transaction))
    }

    public func insert(_ index: Int, content: [Any]) throws {
        if self.doc != nil {
            try self.doc!.transact({ transaction in
                try self.listInsertGenerics(transaction, index: UInt(index), contents: content)
            })
        } else {
            self._prelimContent!.insert(contentsOf: content, at: index)
        }
    }

    /**
     * Appends content to this YArray.
     *
     * @param {Array<T>} content Array of content to append.
     *
     * @todo Use the following implementation in all types.
     */
    public func push(_ content: [Any]) throws {
        if self.doc != nil {
            try self.doc!.transact({ transaction in
                try self.listPushGenerics(transaction, contents: content)
            })
        } else {
            self._prelimContent?.append(contentsOf: content)
        }
    }

    public func unshift(_ content: [Any]) throws {
        try self.insert(0, content: content)
    }

    /**
     * Deletes elements starting from an index.
     *
     * @param {Int} index Index at which to start deleting elements
     * @param {Int} length The Int of elements to remove. Defaults to 1.
     */
    public func delete(_ index: Int, length: Int = 1) throws {
        if self.doc != nil {
            try self.doc!.transact({ transaction in
                try self.listDelete(transaction, index: UInt(index), length: UInt(length))
            })
        } else {
            self._prelimContent!.removeSubrange(index..<index+length)
        }
    }

    /**
     * Returns the i-th element from a YArray.
     *
     * @param {Int} index The index of the element to return from the YArray
     * @return {T}
     */
    public func get(_ index: Int) -> Any? {
        return self.listGet(UInt(index))
    }

    /** Transforms this YArray to a JavaScript Array. */
    public func toArray() -> [Any] {
        return self.listToArray()
    }

    /** Transforms this YArray to a JavaScript Array. */
    public func slice(_ start: Int = 0, end: Int?) -> [Any] {
        let end = end ?? Int(self.length)
        return self.listSlice(start, end: end)
    }

    /**
     * Transforms this Shared Type to a JSON object.
     */
    public func toJSON() -> [Any] {
        return self.map{ c, _ , _ in
            c is AbstractType ? (c as! AbstractType).toJSON() : c
        }
    }

    /**
     * Returns an Array with the result of calling a provided function on every
     * element of this YArray.
     *
     * @template M
     * @param {function(T,Int,YArray<T>):M} f Function that produces an element of the Array
     * @return {Array<M>} A array with each element being the result of the
     *                                 callback function
     */
    public func map<U>(_ body: (Any, Int, YArray) -> U) -> [U] {
        return self.listMap(body: { (element: Any, index: Int) -> U in
            body(element, index, self)
        })
    }

    /**
     * Executes a provided function on once on overy element of this YArray.
     *
     * @param {function(T,Int,YArray<T>):Void} f A function to execute on every element of this YArray.
     */
    public func forEach(_ f: (Any, Int, YArray) -> Void) {
        self.listForEach(body: { value, index in
            f(value, index, self)
        })
    }

//    [Symbol.iterator]() -> IterableIterator<T> {
//        return self.listCreateIterator()
//    }

    public override func _write(_ encoder: UpdateEncoder) {
        encoder.writeTypeRef(YArrayRefID)
    }
}

func readYArray(_decoder: UpdateDecoder) -> YArray {
    return YArray()
}
