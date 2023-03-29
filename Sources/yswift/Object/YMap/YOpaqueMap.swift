//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

final public class YOpaqueMap: YOpaqueObject {
    private var _prelimContent: [String: Any?]?

    public init(_ dict: [String: Any?]? = nil) {
        super.init()
        if dict == nil {
            self._prelimContent = [:]
        } else {
            self._prelimContent = dict
        }
    }
    
    public func removeValue(forKey key: String) {
        if let doc = self.doc {
            doc.transact{ self.mapDelete($0, key: key) }
        } else {
            self._prelimContent?.removeValue(forKey: key)
        }
    }
    
    public subscript(key: String) -> Any? {
        get { self.mapGet(key) }
        set { self.set(key, value: newValue) }
    }

    public func set(_ key: String, value: Any?) {
        if let doc = self.doc {
            doc.transact{ self.mapSet($0, key: key, value: value) }
        } else {
            self._prelimContent![key] = value
        }
    }

    public func contains(_ key: String) -> Bool {
        return self.mapHas(key)
    }

    public func removeAll() {
        if let doc = self.doc {
            doc.transact{ for key in self.keys() { self.mapDelete($0, key: key) } }
        } else {
            self._prelimContent?.removeAll()
        }
    }
    
    public override func copy() -> YOpaqueMap {
        let map = YOpaqueMap()
        for (key, value) in self {
            if let value = value as? YOpaqueObject {
                map.set(key, value: value.copy())
            } else {
                map.set(key, value: value)
            }
        }
        return map
    }

    public override func toJSON() -> Any {
        var map: [String: Any] = [:]
        for (key, item) in storage where !item.deleted {
            let v = item.content.values[item.length - 1]
            if v == nil {
                map[key] = NSNull()
            } else if let v = v as? YOpaqueObject {
                map[key] = v.toJSON()
            } else {
                map[key] = v
            }
        }
        return map
    }
    

    override func _write(_ encoder: YUpdateEncoder) {
        encoder.writeTypeRef(YMapRefID)
    }
    
    override func _integrate(_ y: YDocument, item: YItem?) {
        super._integrate(y, item: item)
        
        for (key, value) in self._prelimContent ?? [:] {
            self.set(key, value: value)
        }
        self._prelimContent = nil
    }

    override func _copy() -> YOpaqueMap {
        return YOpaqueMap()
    }

    override func _callObserver(_ transaction: YTransaction, _parentSubs: Set<String?>) {
        self.callObservers(transaction: transaction, event: YOpaqueMapEvent(self, transaction: transaction, keysChanged: _parentSubs))
    }
}

extension YOpaqueMap {
    public var count: Int {
        self.storage.lazy.filter{ _, v in !v.deleted }.count
    }
    public var isEmpty: Bool {
        self.storage.lazy.filter{ _, v in !v.deleted }.isEmpty
    }
    
    public func keys() -> some Sequence<String> {
        self.storage.lazy.filter{ _, v in !v.deleted }
            .map{ key, _ in key }
    }
    public func values() -> some Sequence<Any?> {
        self.storage.lazy.filter{ _, v in !v.deleted }
            .map{ _, c in c.content.values[c.length - 1] }
    }
}

extension YOpaqueMap: Sequence {
    public typealias Element = (key: String, value: Any?)
    
    public func makeIterator() -> some IteratorProtocol<Element> {
        self.storage.lazy.filter{ _, v in !v.deleted }
            .map{ ($0, $1.content.values[$1.length - 1]) }
            .makeIterator()
    }
}

extension YOpaqueMap: CustomStringConvertible {
    public var description: String { String(describing: self.toJSON()) }
}


func readYMap(_decoder: YUpdateDecoder) -> YOpaqueMap {
    return YOpaqueMap()
}
