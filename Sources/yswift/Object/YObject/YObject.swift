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
    
    enum InitContext {
        case unspecified
        case decode
        // [old:new], [old.raw:new_writer]
        case smartcopy(RefDictionary<YObjectID, YObjectID>, RefDictionary<YObjectID, (YObjectID) -> ()>)
    }
    
    static let objectIDKey = "_"
    static var initContext: InitContext = .unspecified
    static var typeIDTable: [ObjectIdentifier: Int] = [:]
    
    public private(set) var objectID: YObjectID!
    
    internal var _prelimContent: [String: Any?] = [:]
    internal var _propertyTable: [String: any _YObjectProperty] = [:]
    
    public required override init() {
        switch YObject.initContext {
        case .decode: self.objectID = nil
        case .smartcopy, .unspecified: self.objectID = .publish()
        }
        
        super.init()
                
        self.observe{[unowned self] event, _ in
            guard let event = event as? YObjectEvent else { return }
            for case let key? in event.keysChanged {
                self._propertyTable[key]?.send(self.mapGet(key))
            }
        }
        
        switch YObject.initContext {
        case .decode: break
        default:
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

    public override func copy() -> Self {
        let map = Self()
        if case .smartcopy(let table, _) = YObject.initContext {
            table[self.objectID] = map.objectID
        }
        for (key, value) in self.elementSequence() {
            if case .smartcopy(_, let writers) = YObject.initContext, key.starts(with: "&") {
                self._copyWithSmartCopy(map: map, value: value, key: key, writers: writers)
            } else if let value = value as? YOpaqueObject {
                map._setValue(value.copy(), for: key)
            } else {
                map._setValue(value, for: key)
            }
        }
        return map
    }
    
    func _getValue(for key: String) -> Any? {
        if self.document != nil { return self.mapGet(key) }
        return _prelimContent[key] ?? nil
    }
    func _setValue(_ value: Any?, for key: String) {
        if let doc = self.document {
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
    func elementSequence() -> AnySequence<(String, Any?)> {
        if self.document == nil {
            return AnySequence(self._prelimContent.lazy
                .map{ ($0, $1) })
        } else {
            return AnySequence(self.storage.lazy.filter{ _, v in !v.deleted }
                .map{ ($0, $1.content.values[$1.length - 1]) })
        }
    }
}
