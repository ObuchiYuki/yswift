//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation
 
public class YObject: JSHashable {
        
    // =========================================================================== //
    // MARK: - Property -
    var doc: Doc? = nil

    public var parent: YObject? { self.item?.parent?.object }
    
    var item: YItem? = nil
    
    var storage: [String: YItem] = [:]
    
    var serchMarkers: RefArray<YArraySearchMarker>? = nil

    var _start: YItem? = nil
    var _length: Int = 0
    
    let _eventHandler: YEventHandler<(event: YEvent, YTransaction)> = YEventHandler()
    let _deepEventHandler: YEventHandler<(events: [YEvent], YTransaction)> = YEventHandler()

    var _first: YItem? {
        var item = self._start
        while let uitem = item, uitem.deleted { item = uitem.right as? YItem }
        return item
    }

    // =========================================================================== //
    // MARK: - Abstract Methods -

    public func clone() throws -> Self { fatalError() }

    func _copy() -> YObject { fatalError() }

    // =========================================================================== //
    // MARK: - Methods -

    public init() {}

    func getChildren() -> [YItem] {
        var item = self._start
        var arr: [YItem] = []
        while (item != nil) {
            arr.append(item!)
            item = item!.right as? YItem
        }
        return arr
    }

    func isParentOf(child: YItem?) -> Bool {
        var child = child
        while (child != nil) {
            if child!.parent?.object === self { return true }
            child = child?.parent?.object?.item
        }
        return false
    }

    func callObservers(transaction: YTransaction, event: YEvent) throws {
        var type = self
        let changedType = type
        
        while true {
            if transaction.changedParentTypes[type] == nil { transaction.changedParentTypes[type] = [] }
            transaction.changedParentTypes[type]!.append(event)
            guard let object = type.item?.parent?.object else { break }
            type = object
        }
        
        try changedType._eventHandler.callListeners((event, transaction))
    }

    // =========================================================================== //
    // MARK: - Private Methods (Temporally public) -
    
    func _integrate(_ y: Doc, item: YItem?) throws {
        self.doc = y
        self.item = item
    }

    func _write(_ _encoder: YUpdateEncoder) {}

    func _callObserver(_ transaction: YTransaction, _parentSubs: Set<String?>) throws {
        if !transaction.local && self.serchMarkers != nil {
            self.serchMarkers!.value.removeAll()
        }
    }

    /** Observe all events that are created on this type. */
    @discardableResult
    public func observe(_ f: @escaping (YEvent, YTransaction) throws -> Void) -> UUID {
        self._eventHandler.addListener(f)
    }

    /** Observe all events that are created by this type and its children. */
    @discardableResult
    public func observeDeep(_ f: @escaping ([YEvent], YTransaction) throws -> Void) -> UUID {
        self._deepEventHandler.addListener(f)
    }

    /** Unregister an observer function. */
    public func unobserve(_ disposer: UUID) {
        self._eventHandler.removeListener(disposer)
    }

    /** Unregister an observer function. */
    public func unobserveDeep(_ disposer: UUID) {
        self._deepEventHandler.removeListener(disposer)
    }

    public func toJSON() -> Any? {
        fatalError()
    }
}

extension YObject {
    func findRootTypeKey() throws -> String {
        for (key, value) in self.doc?.share ?? [:] {
            if value === self { return key }
        }
        throw YSwiftError.unexpectedCase
    }
}
