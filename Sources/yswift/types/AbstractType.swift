//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation
 
public class AbstractType: JSHashable {
    
    public typealias EventType = YEvent
    
    // =========================================================================== //
    // MARK: - Property -
    public var doc: Doc? = nil

    public var parent: AbstractType? {
        return self._item != nil ? (self._item!.parent as! AbstractType) : nil
    }

    // =========================================================================== //
    // MARK: - Private (Temporally public) -
    public var _item: Item? = nil
    public var _map: [String: Item] = [:]
    public var _start: Item? = nil
    public var _length: UInt = 0
    public var _eH: EventHandler<EventType, Transaction> = EventHandler() /** Event handlers */
    public var _dEH: EventHandler<[YEvent], Transaction> = EventHandler() /** Deep event handlers */
    public var _searchMarker: [ArraySearchMarker]? = nil

     /** The first non-deleted item */
    public var _first: Item? {
        var n = self._start
        while (n != nil && n!.deleted) { n = n!.right }
        return n
    }

    // =========================================================================== //
    // MARK: - Abstract Methods -

    public func clone() throws -> AbstractType { fatalError() }

    public func _copy() -> AbstractType { fatalError() }

    // =========================================================================== //
    // MARK: - Methods -

    public init() {}

    public func getChildren() -> [Item] {
        var item = self._start
        var arr: [Item] = []
        while (item != nil) {
            arr.append(item!)
            item = item!.right
        }
        return arr
    }

    public func isParentOf(child: Item?) -> Bool {
        var child = child
        while (child != nil) {
            if child!.parent is AbstractType && (child!.parent as! AbstractType) === self { return true }
            child = (child!.parent as! AbstractType)._item
        }
        return false
    }

    public func callObservers(transaction: Transaction, event: EventType) {
        var type = self
        let changedType = type
        
        while (true) {
            if transaction.changedParentTypes[type] == nil { transaction.changedParentTypes[type] = [] }
            transaction.changedParentTypes[type]!.append(event)
            if type._item == nil { break }
            type = type._item!.parent as! AbstractType
        }
        changedType._eH.callListeners(event, transaction)
    }

    public func listSlice(_ start: Int, end: Int) -> [Any] {
        var start = start, end = end
        
        if start < 0 { start = Int(self._length) + start }
        if end < 0 { end = Int(self._length) + end }
        var len = end - start
        var cs: [Any] = []
        var n = self._start
        while (n != nil && len > 0) {
            if n!.countable && !n!.deleted {
                let c = n!.content.getContent()
                if c.count <= start {
                    start -= c.count
                } else {
                    var i = Int(start); while i < c.count && len > 0 {
                        cs.append(c[i])
                        len -= 1
                        i += 1
                    }
                    start = 0
                }
            }
            n = n!.right
        }
        return cs
    }

    public func listToArray() -> [Any] {
        var cs: [Any] = []
        var n = self._start
        while (n != nil) {
            if n!.countable && !n!.deleted {
                let c = n!.content.getContent()
                for i in 0..<c.count {
                    cs.append(c[i])
                }
            }
            n = n!.right
        }
        return cs
    }

    public func listToArraySnapshot(_ snapshot: Snapshot) -> [Any] {
        var cs: [Any] = []
        var n = self._start
        while (n != nil) {
            if n!.countable && n!.isVisible(snapshot) {
                let c = n!.content.getContent()
                for i in 0..<c.count {
                    cs.append(c[i])
                }
            }
            n = n!.right
        }
        return cs
    }

    /** Executes a provided function on once on overy element of this YArray. */
    public func listForEach(body: (Any, Int) -> Void) {
        var index = 0
        var item = self._start
        while (item != nil) {
            if item!.countable && !item!.deleted {
                let c = item!.content.getContent()
                for i in 0..<c.count {
                    body(c[i], index)
                    index += 1
                }
            }
            item = item!.right
        }
    }

    public func listMap<R>(body: (Any, Int) -> R) -> [R] {
        var result: [R] = []
        self.listForEach{ element, index in
            result.append(body(element, index))
        }
        return result
    }

    public func listCreateIterator() -> any IteratorProtocol<Any> {
        var item = self._start
        var currentContent: [Any]? = nil
        var currentContentIndex = 0
        
        return AnyIterator<Any>{ () -> Any? in
            // find some content
            if currentContent == nil {
                while (item != nil && item!.deleted) { item = item!.right }
                if item == nil {
                    return nil
                }
                currentContent = item!.content.getContent()
                currentContentIndex = 0
                item = item!.right
            }
            let value = currentContent![currentContentIndex]
            currentContentIndex += 1
            if currentContent!.count <= currentContentIndex { currentContent = nil }
            return value
        }
    }

    /**
     * Executes a provided function on once on overy element of this YArray.
     * Operates on a snapshotted state of the document.
     */
    public func listForEachSnapshot(_ body: (Any, Int) -> Void, snapshot: Snapshot) {
        var index = 0
        var item = self._start
        while (item != nil) {
            if item!.countable && item!.isVisible(snapshot) {
                let c = item!.content.getContent()
                for i in 0..<c.count {
                    body(c[i], index)
                    index += 1
                }
            }
            item = item!.right
        }
    }

    public func listGet(_ index: UInt) -> Any? {
        var index = index
        let marker = ArraySearchMarker.find(self, index: index)
        var item = self._start
        if marker != nil {
            item = marker!.item
            index -= marker!.index
        }
        while item != nil {
            if !item!.deleted && item!.countable {
                if index < item!.length {
                    return item!.content.getContent()[Int(index)]
                }
                index -= item!.length
            }
            
            item = item!.right
        }
        
        return nil
    }

    // this -> parent
    public func listInsertGenericsAfter(_ transaction: Transaction, referenceItem: Item?, contents: [Any?]) throws {
        var left = referenceItem
        let doc = transaction.doc
        let ownClientId = doc.clientID
        let store = doc.store
        let right = referenceItem == nil ? self._start : referenceItem!.right

//        type JsonContent = { [s: String]: JsonContent } | JsonContent[] | Int? | String

        var jsonContent: [Any?] = []

        func packJsonContent() throws {
            if (jsonContent.count <= 0) { return }
            let id = ID(client: ownClientId, clock: store.getState(ownClientId))
            let content = ContentAny(jsonContent)
            left = Item(id: id, left: left, origin: left?.lastID, right: right, rightOrigin: right?.id, parent: self, parentSub: nil, content: content)
            try left!.integrate(transaction: transaction, offset: 0)
            jsonContent = []
        }

        try contents.forEach{ content in
            if content == nil {
                jsonContent.append(content)
            } else {
                if (
                    content is Int ||
                    content is Dictionary<AnyHashable, Any> ||
                    content is Bool ||
                    content is Array<Any> ||
                    content is String
                ) {
                    jsonContent.append(content)
                } else {
                    try packJsonContent()
                    if (content is Data) {
                        let id = ID(client: ownClientId, clock: store.getState(ownClientId))
                        let icontent = ContentBinary(content as! Data)
                        left = Item(id: id, left: left, origin: left?.lastID, right: right, rightOrigin: right?.id, parent: self, parentSub: nil, content: icontent)
                        try left!.integrate(transaction: transaction, offset: 0)
                    } else if content is Doc {
                        let id = ID(client: ownClientId, clock: store.getState(ownClientId))
                        let icontent = ContentDoc(content as! Doc)
                        left = Item(id: id, left: left, origin: left?.lastID, right: right, rightOrigin: right?.id, parent: self, parentSub: nil, content: icontent)
                        try left!.integrate(transaction: transaction, offset: 0)
                    } else if type(of: content) == AbstractType.self {
                        let id = ID(client: ownClientId, clock: store.getState(ownClientId))
                        let icontent = ContentType(content as! AbstractType)
                        left = Item(id: id, left: left, origin: left?.lastID, right: right, rightOrigin: right?.id, parent: self, parentSub: nil, content: icontent)
                        try left!.integrate(transaction: transaction, offset: 0)
                    } else {
                        throw YSwiftError.unexpectedContentType
                    }
                }
            }
        }
        
        try packJsonContent()
    }

    // this -> parent
    public func listInsertGenerics(_ transaction: Transaction, index: UInt, contents: [Any]) throws {
        var index = index
        if index > self._length { throw YSwiftError.lengthExceeded }

        if index == 0 {
            if self._searchMarker != nil {
                ArraySearchMarker.updateChanges(&self._searchMarker!, index: index, len: UInt(contents.count))
            }
            return try self.listInsertGenericsAfter(transaction, referenceItem: nil, contents: contents)
        }
        let startIndex = index
        let marker = ArraySearchMarker.find(self, index: index)
        var n = self._start
        if marker != nil {
            n = marker!.item
            index -= marker!.index
            // we need to iterate one to the left so that the algorithm works
            if index == 0 {
                n = n!.prev
                index += (n != nil && n!.countable && !n!.deleted) ? n!.length : 0
            }
        }
        
        while n != nil {
            if !n!.deleted && n!.countable {
                if index <= n!.length {
                    if index < n!.length {
                        let id = ID(client: n!.id.client, clock: n!.id.clock + index)
                        try StructStore.getItemCleanStart(transaction, id: id)
                    }
                    break
                }
                index -= n!.length
            }
            n = n!.right
        }
        if (self._searchMarker != nil) {
            ArraySearchMarker.updateChanges(&self._searchMarker!, index: startIndex, len: UInt(contents.count))
        }
        return try self.listInsertGenericsAfter(transaction, referenceItem: n, contents: contents)
    }
    
    public func listPushGenerics(_ transaction: Transaction, contents: [Any]) throws {
        
        let marker = (self._searchMarker ?? [])
            .reduce(ArraySearchMarker(item: self._start, index: 0)) { maxMarker, currMarker in
                return currMarker.index > maxMarker.index ? currMarker : maxMarker
            }
    
        var item = marker.item
        while (item?.right != nil) { item = item!.right }
        return try self.listInsertGenericsAfter(transaction, referenceItem: item, contents: contents)
    }


    /** this -> parent */
    public func listDelete(_ transaction: Transaction, index: UInt, length: UInt) throws {
        var index = index, length = length
        
        if length == 0 { return }
        let startIndex = index
        let startLength = length
        let marker = ArraySearchMarker.find(self, index: index)
        var item = self._start
        if marker != nil {
            item = marker!.item
            index -= marker!.index
        }
        // compute the first item to be deleted
        while item != nil && index > 0 {
            if !item!.deleted && item!.countable {
                if index < item!.length {
                    let id = ID(client: item!.id.client, clock: item!.id.clock + index)
                    _ = try StructStore.getItemCleanStart(transaction, id: id)
                }
                index -= item!.length
            }
            
            item = item!.right
        }
        
        while (length > 0 && item != nil) {
            if !item!.deleted {
                if length < item!.length {
                    let id = ID(client: item!.id.client, clock: item!.id.clock + length)
                    _ = try StructStore.getItemCleanStart(transaction, id: id)
                }
                item!.delete(transaction)
                length -= item!.length
            }
            item = item!.right
        }
        if length > 0 {
            throw YSwiftError.lengthExceeded
        }
        if (self._searchMarker != nil) {
            ArraySearchMarker.updateChanges(&self._searchMarker!, index: startIndex, len: length - startLength)
        }
    }


    // this -> parent
    public func mapDelete(_ transaction: Transaction, key: String) {
        let c = self._map[key]
        if c != nil {
            c!.delete(transaction)
        }
    }

    // this -> parent
    public func mapSet(_ transaction: Transaction, key: String, value: Any?) throws {
        let left = self._map[key]
        let doc = transaction.doc
        let ownClientId = doc.clientID
        var content: any Content
        if value == nil {
            content = ContentAny([value])
        } else {
            if value! is Int || value! is [String: Any] || value! is Bool || value! is [Any] || value! is String {
                content = ContentAny([value])
            } else if value! is Data {
                content = ContentBinary(value as! Data)
            } else if value! is Doc {
                content = ContentDoc(value as! Doc)
            } else {
                if value! is AbstractType {
                    content = ContentType(value as! AbstractType)
                } else {
                    throw YSwiftError.unexpectedContentType
                }
            }
        }
        let id = ID(client: ownClientId, clock: doc.store.getState(ownClientId))
        try Item(id: id, left: left, origin: left?.lastID, right: nil, rightOrigin: nil, parent: self, parentSub: key, content: content)
            .integrate(transaction: transaction, offset: 0)
    }

    // this -> parent
    public func mapGet(_ key: String) -> Any? {
        let val = self._map[key]
        return val != nil && !val!.deleted ? val!.content.getContent()[Int(val!.length) - 1] : nil
    }

    // this -> parent
    public func mapGetAll() -> [String: Any?] {
        var res: [String: Any?] = [:]
        self._map.forEach({ key, value in
            if !value.deleted {
                res[key] = value.content.getContent()[Int(value.length) - 1]
            }
        })
        return res
    }
    
    // this -> parent
    public func mapHas(_ key: String) -> Bool {
        let val = self._map[key]
        return val != nil && !val!.deleted
    }

    // this -> parent
    public func mapGetSnapshot(_ key: String, snapshot: Snapshot) -> Any? {
        var v = self._map[key]
        while (v != nil && (snapshot.sv[v!.id.client] == nil || v!.id.clock >= (snapshot.sv[v!.id.client] ?? 0))) {
            v = v!.left
        }
        return v != nil && v!.isVisible(snapshot) ? v!.content.getContent()[Int(v!.length) - 1] : nil
    }

    // =========================================================================== //
    // MARK: - Private Methods (Temporally public) -
    
    public func _integrate(_ y: Doc, item: Item?) throws {
        self.doc = y
        self._item = item
    }

    public func _write(_ _encoder: UpdateEncoder) {}

    public func _callObserver(_ transaction: Transaction, _parentSubs: Set<String?>) throws {
        if !transaction.local && self._searchMarker != nil {
            self._searchMarker!.removeAll()
        }
    }

    /** Observe all events that are created on this type. */
    public func observe(_ f: @escaping (EventType, Transaction) -> Void) -> EventHandler.Disposer {
        self._eH.addListener(f)
    }

    /** Observe all events that are created by this type and its children. */
    public func observeDeep(_ f: @escaping ([YEvent], Transaction) -> Void) -> EventHandler.Disposer {
        self._dEH.addListener(f)
    }

    /** Unregister an observer function. */
    public func unobserve(_ disposer: EventHandler.Disposer) {
        self._eH.removeListener(disposer)
    }

    /** Unregister an observer function. */
    public func unobserveDeep(_ disposer: EventHandler.Disposer) {
        self._dEH.removeListener(disposer)
    }

    public func toJSON() -> Any {
        fatalError()
    }
}
