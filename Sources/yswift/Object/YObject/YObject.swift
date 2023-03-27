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
    public var doc: Doc? = nil

    public var parent: YObject? { self.item?.parent?.object }
    
    public var item: Item? = nil
    
    var storage: [String: Item] = [:]
    
    var serchMarkers: RefArray<ArraySearchMarker>? = nil

    var _start: Item? = nil
    var _length: Int = 0
    
    let _eventHandler: EventHandler<YEvent, Transaction> = EventHandler()
    let _deepEventHandler: EventHandler<[YEvent], Transaction> = EventHandler()

    var _first: Item? {
        var item = self._start
        while let uitem = item, uitem.deleted { item = uitem.right as? Item }
        return item
    }

    // =========================================================================== //
    // MARK: - Abstract Methods -

    public func clone() throws -> Self { fatalError() }

    func _copy() -> YObject { fatalError() }

    // =========================================================================== //
    // MARK: - Methods -

    public init() {}

    func getChildren() -> [Item] {
        var item = self._start
        var arr: [Item] = []
        while (item != nil) {
            arr.append(item!)
            item = item!.right as? Item
        }
        return arr
    }

    func isParentOf(child: Item?) -> Bool {
        var child = child
        while (child != nil) {
            if child!.parent?.object === self { return true }
            child = child?.parent?.object?.item
        }
        return false
    }

    func callObservers(transaction: Transaction, event: YEvent) throws {
        var type = self
        let changedType = type
        
        while true {
            if transaction.changedParentTypes[type] == nil { transaction.changedParentTypes[type] = [] }
            transaction.changedParentTypes[type]!.append(event)
            guard let object = type.item?.parent?.object else { break }
            type = object
        }
        
        try changedType._eventHandler.callListeners(event, transaction)
    }

    // =========================================================================== //
    // MARK: - Private Methods (Temporally public) -
    
    func _integrate(_ y: Doc, item: Item?) throws {
        self.doc = y
        self.item = item
    }

    func _write(_ _encoder: YUpdateEncoder) {}

    func _callObserver(_ transaction: Transaction, _parentSubs: Set<String?>) throws {
        if !transaction.local && self.serchMarkers != nil {
            self.serchMarkers!.value.removeAll()
        }
    }

    /** Observe all events that are created on this type. */
    @discardableResult
    public func observe(_ f: @escaping (YEvent, Transaction) throws -> Void) -> EventHandler.Disposer {
        self._eventHandler.addListener(f)
    }

    /** Observe all events that are created by this type and its children. */
    @discardableResult
    public func observeDeep(_ f: @escaping ([YEvent], Transaction) throws -> Void) -> EventHandler.Disposer {
        self._deepEventHandler.addListener(f)
    }

    /** Unregister an observer function. */
    public func unobserve(_ disposer: EventHandler.Disposer) {
        self._eventHandler.removeListener(disposer)
    }

    /** Unregister an observer function. */
    public func unobserveDeep(_ disposer: EventHandler.Disposer) {
        self._deepEventHandler.removeListener(disposer)
    }

    public func toJSON() -> Any? {
        fatalError()
    }
}
