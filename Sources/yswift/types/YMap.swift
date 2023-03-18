//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

public class YMapEvent: YEvent {
    public var keysChanged: Set<String?>

    public init(_ ymap: YMap, transaction: Transaction, keysChanged: Set<String?>) {
        self.keysChanged = keysChanged
        super.init(ymap, transaction: transaction)
    }
}

public class YMap: AbstractType {
    public var _prelimContent: [String: Any]?

    public init(_ dict: [String: Any]? = nil) {
        super.init()
        self._prelimContent = nil

        if dict == nil {
            self._prelimContent = [:]
        } else {
            self._prelimContent = dict
        }
    }

    public override func _integrate(_ y: Doc, item: Item?) throws {
        try super._integrate(y, item: item)
        
        try self._prelimContent!.forEach({ key, value in
            try self.set(key, value: value)
        })
        self._prelimContent = nil
    }

    public override func _copy() -> YMap {
        return YMap()
    }

    public override func clone() throws -> YMap {
        let map = YMap()
        try self.forEach({ value, key, _ in
            try map.set(key, value: value is AbstractType ? (value as! AbstractType).clone() : value)
        })
        return map
    }

    /**
     * Creates YMapEvent and calls observers.
     *
     * @param {Transaction} transaction
     * @param {Set<nil|String>} parentSubs Keys changed on this type. `nil` if list was modified.
     */
    public override func _callObserver(_ transaction: Transaction, _parentSubs: Set<String?>) throws {
        try self.callObservers(transaction: transaction, event: YMapEvent(self, transaction: transaction, keysChanged: _parentSubs))
    }

    /** Transforms this Shared Type to a JSON object. */
    public override func toJSON() -> Any {
        var map: [String: Any] = [:]
        self._map.forEach({ key, item in
            if !item.deleted {
                let v = item.content.getContent()[Int(item.length) - 1]
                map[key] = v is AbstractType ? (v as! AbstractType).toJSON() : v
            }
        })
        return map
    }

//    private public func createMapIterator() -> IterableIterator<any[]> {
//        return Lib0filterIterator(self._map.entries(), entry -> !entry[1].deleted)
//    }

//    /** Returns the size of the YMap (count of key/value pairs) */
//    get public func size() -> Int {
//        return [...self.createMapIterator()].length
//    }
//
//    /** Returns the keys for each element in the YMap Type. */
//    public func keys() -> IterableIterator<String> {
//        return Lib0mapIterator(self.createMapIterator(), (v: [any]) -> v[0])
//    }
//
//    /** Returns the values for each element in the YMap Type. */
//    public func values() -> IterableIterator<any> {
//        return Lib0mapIterator(self.createMapIterator(), (v: any) -> v[1].content.getContent()[v[1].length - 1])
//    }
//
//    /** Returns an Iterator of [key, value] pairs */
//    public func entries() -> IterableIterator<any> {
//        return Lib0mapIterator(self.createMapIterator(), (v: any) -> [v[0], v[1].content.getContent()[v[1].length - 1]])
//    }

    /** Executes a provided function on once on every key-value pair. */
    public func forEach(_ f: (Any, String, YMap) throws -> Void) rethrows {
        try self._map.forEach({ key, item in
            if !item.deleted {
                try f(item.content.getContent()[Int(item.length) - 1], key, self)
            }
        })
    }

//    /** Returns an Iterator of [key, value] pairs */
//    [Symbol.iterator]() -> IterableIterator<any> {
//        return self.entries()
//    }

    /** Remove a specified element from this YMap. */
    public func delete(_ key: String) throws {
        if self.doc != nil {
            try self.doc!.transact({ transaction in
                self.mapDelete(transaction, key: key)
            })
        } else {
            self._prelimContent!.removeValue(forKey: key)
        }
    }

    /** Adds or updates an element with a specified key and value. */
    public func set(_ key: String, value: Any) throws {
        if self.doc != nil {
            try self.doc!.transact({ transaction in
                try self.mapSet(transaction, key: key, value: value)
            })
        } else {
            self._prelimContent![key] = value
        }
    }

    /** Returns a specified element from this YMap. */
    public func get(_ key: String) -> Any? {
        return self.mapGet(key)
    }

    /** Returns a Bool indicating whether the specified key exists or not. */
    public func has(_ key: String) -> Bool {
        return self.mapHas(key)
    }

    /** Removes all elements from this YMap. */
    public func clear() throws {
        if self.doc != nil {
            try self.doc!.transact({ transaction in
                self.forEach({ _, key, map in
                    map.mapDelete(transaction, key: key)
                })
            })
        } else {
            self._prelimContent!.removeAll()
        }
    }

    public override func _write(_ encoder: UpdateEncoder) {
        encoder.writeTypeRef(YMapRefID)
    }
}

func readYMap(_decoder: UpdateDecoder) -> YMap {
    return YMap()
}
