//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation
import Combine

final public class YObjectEvent: YEvent {
    public var keysChanged: Set<String?>

    init(_ object: YObject, transaction: YTransaction, keysChanged: Set<String?>) {
        self.keysChanged = keysChanged
        super.init(object, transaction: transaction)
    }
}

open class YObject: YOpaqueObject {
    private var _prelimContent: [String: Any?]? = [:]
    private var _propertyTable: [String: _YObjectProperty] = [:]
        
    public override required init() {
        super.init()
        
        self.observe{[unowned self] event, _ in
            guard let event = event as? YObjectEvent else { return }
            for case let key? in event.keysChanged {
                self._propertyTable[key]?.send(self.mapGet(key))
            }
        }
    }
    
    public func register<T: YElement>(_ property: Property<T>, for key: String) {
        self._propertyTable[key] = property
        property.storage.setter = {[unowned self] in try! self._setValue($0.encodeToOpaque(), for: key) }
        property.storage.getter = {[unowned self] in T.decode(from: self._getValue(for: key)) }
        if !YObject.decodingFromContent { try! self._setValue(property.initialValue().encodeToOpaque(), for: key) }
    }
    
    public func register<T: YElement>(_ property: YArray<T>, for key: String) {
        try! self._setValue(property.opaque, for: key)
    }
    
    public func register<T: YElement>(_ property: YMap<T>, for key: String) {
        try! self._setValue(property.opaque, for: key)
    }

    public override func copy() throws -> Self {
        let map = Self()
        for (key, value) in self.elementSequence() {
            if let value = value as? YOpaqueObject {
                try map._setValue(value.copy(), for: key)
            } else {
                try map._setValue(value, for: key)
            }
        }
        return map
    }
    
    private func _getValue(for key: String) -> Any? {
        if self.doc != nil {
            return self.mapGet(key)
        } else {
            return _prelimContent?[key] ?? nil
        }
    }
    private func _setValue(_ value: Any?, for key: String) throws {
        if let doc = self.doc {
            try doc.transact{ try self.mapSet($0, key: key, value: value) }
        } else {
            self._prelimContent?[key] = value
            self._propertyTable[key]?.send(value)
        }
    }

    override func _write(_ encoder: YUpdateEncoder) {
        guard let typeID = YObject.typeIDTable[ObjectIdentifier(type(of: self))] else {
            fatalError("This object is not registerd.")
        }
        encoder.writeTypeRef(typeID)
    }
    
    override func _integrate(_ y: YDocument, item: YItem?) throws {
        try super._integrate(y, item: item)
        
        for (key, value) in self._prelimContent ?? [:] {
            try self._setValue(value, for: key)
        }
        self._prelimContent = nil
    }

    override func _copy() -> YOpaqueMap {
        return YOpaqueMap()
    }

    override func _callObserver(_ transaction: YTransaction, _parentSubs: Set<String?>) throws {
        try self.callObservers(
            transaction: transaction,
            event: YObjectEvent(self, transaction: transaction, keysChanged: _parentSubs)
        )
    }
}

extension YObject {
    private static var typeIDTable: [ObjectIdentifier: Int] = [:]
    private static var decodingFromContent = false
    
    public class func register(_ typeID: UInt) {
        let nTypeID = Int(typeID) + 7
        self.typeIDTable[ObjectIdentifier(self)] = nTypeID
        YObjectContent.register(for: nTypeID) {_ in
            self.decodingFromContent = true
            defer { self.decodingFromContent = false }
            return Self()
        }
    }
    
    public class func unregister() {
        guard let typeID = self.typeIDTable[ObjectIdentifier(self)] else { return }
        YObjectContent.unregister(for: typeID)
    }
}

extension YObject {
    private func elementSequence() -> some Sequence<(String, Any?)> {
        self.storage.lazy.filter{ _, v in !v.deleted }
            .map{ ($0, $1.content.values[$1.length - 1]) }
    }
}

extension YObject: CustomStringConvertible {
    public var description: String {
        let components = self.elementSequence()
            .map{ "\($0): \($1.map{ String(reflecting: $0) } ?? "nil")" }
            .joined(separator: ", ")
        return "\(Self.self)(\(components))"
    }
}
