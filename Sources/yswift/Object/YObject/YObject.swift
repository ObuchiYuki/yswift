//
//  File.swift
//
//
//  Created by yuki on 2023/03/16.
//

import Foundation
import Combine
import Promise

final public class YObjectEvent: YEvent {
    public var keysChanged: Set<String?>

    init(_ object: YObject, transaction: YTransaction, keysChanged: Set<String?>) {
        self.keysChanged = keysChanged
        super.init(object, transaction: transaction)
    }
}

open class YObject: YOpaqueObject {
    
    private static let objectIDKey = "_"
    public private(set) var objectID: YObjectID!
    
    private var _prelimContent: [String: Any?] = [:]
    private var _propertyTable: [String: _YObjectProperty] = [:]
    
    public required override init() {
        if YObject.decodingFromContent { // decode
            self.objectID = nil
        } else { // initial make
            self.objectID = .publish()
        }
        
        super.init()
                
        self.observe{[unowned self] event, _ in
            guard let event = event as? YObjectEvent else { return }
            for case let key? in event.keysChanged {
                self._propertyTable[key]?.send(self.mapGet(key))
            }
        }
        
        if !YObject.decodingFromContent {
            self._setValue(self.objectID.value, for: YObject.objectIDKey)
            YObjectStore.shared.register(self)
        }
    }
    
    override func _onStorageUpdated() {
        guard self.objectID == nil, self.storage[YObject.objectIDKey] != nil else { return }
        let id = self.mapGet(YObject.objectIDKey) as! Int
        self.objectID = YObjectID(id)
        YObjectStore.shared.register(self)
    }
    
    public func register<T: YElement>(_ property: Property<T>, for key: String) {
        self._propertyTable[key] = property
        property.storage.setter = {[unowned self] in self._setValue($0.encodeToOpaque(), for: key) }
        property.storage.getter = {[unowned self] in T.decode(from: self._getValue(for: key)) }
        if !YObject.decodingFromContent {
            self._setValue(property.initialValue().encodeToOpaque(), for: key)
        }
    }
    
    public func register<T: YWrapperObject>(_ property: WProperty<T>, for key: String) {
        property.storage.getter = {[unowned self] in T.decode(from: self._getValue(for: key)) }
        if !YObject.decodingFromContent {
            self._setValue(property.initialValue().opaque, for: key)
        }
    }
    
    public override func copy() -> Self {
        let map = Self()
        for (key, value) in self.elementSequence() {
            if let value = value as? YOpaqueObject {
                map._setValue(value.copy(), for: key)
            } else {
                map._setValue(value, for: key)
            }
        }
        return map
    }
    
    private func _getValue(for key: String) -> Any? {
        if self.doc != nil { return self.mapGet(key) }
        return _prelimContent[key] ?? nil
    }
    private func _setValue(_ value: Any?, for key: String) {
        if let doc = self.doc {
            doc.transact{ self.mapSet($0, key: key, value: value) }
        } else {
            self._prelimContent[key] = value
            self._propertyTable[key]?.send(value)
        }
    }

    override func _write(_ encoder: YUpdateEncoder) {
        guard let typeID = YObject.typeIDTable[ObjectIdentifier(type(of: self))] else {
            fatalError("This object is not registerd.")
        }
        encoder.writeTypeRef(typeID)
    }
    
    override func _integrate(_ y: YDocument, item: YItem?) {
        super._integrate(y, item: item)
                
        for (key, value) in self._prelimContent {
            self._setValue(value, for: key)
        }
        self._prelimContent.removeAll()
    }

    override func _copy() -> YObject { return Self() }

    override func _callObserver(_ transaction: YTransaction, _parentSubs: Set<String?>) {
        self.callObservers(
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
    private func elementSequence() -> AnySequence<(String, Any?)> {
        if self.doc == nil {
            return AnySequence(self._prelimContent.lazy
                .map{ ($0, $1) })
        } else {
            return AnySequence(self.storage.lazy.filter{ _, v in !v.deleted }
                .map{ ($0, $1.content.values[$1.length - 1]) })
        }
    }
}

extension YObject: CustomStringConvertible {
    public var description: String {
        var components = [String]()
                
        for var (key, value) in self.elementSequence().sorted(by: { $0.0 < $1.0 }) {
            if key == YObject.objectIDKey {
                value = YObjectID(value as! Int).compressedString()
                key = "_"
            }
            
            if let _value = value, !(_value is NSNull) {
                if let property = self._propertyTable[key], String(describing: type(of: property)).contains("YObjectReference") {
                    value = YObjectID(value as! Int).compressedString()
                }
                value = String(reflecting: value!)
            } else {
                value = "nil"
            }
            
            components.append("\(key): \(value!)")
        }
        
        return "\(Self.self)(\(components.joined(separator: ", ")))"
    }
}

