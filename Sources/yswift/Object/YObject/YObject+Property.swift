//
//  File.swift
//
//
//  Created by yuki on 2023/03/28.
//

import Foundation
import Combine

extension YObject {
    public func register<T: YElement>(_ property: Property<T>, for key: String) {
        assert(!key.starts(with: "&"))
        self._registerProperty(property, for: key)
    }
    
    public func register<T: YObject>(_ property: Property<YReference<T>>, for key: String) {
        self._registerProperty(property, for: "&\(key)")
    }
    
    private func _registerProperty(_ property: any _YObjectProperty, for key: String) {
        self._propertyTable[key] = property
        property.storage.setter = {[unowned self] in self._setValue($0, for: key) }
        property.storage.getter = {[unowned self] in self._getValue(for: key) }
        if case .decode = YObject.initContext {} else {
            self._setValue(property.initialValue(), for: key)
        }
    }
}

protocol _YObjectPropertyStorage {
    var setter: ((Any?) -> ())! { get nonmutating set }
    var getter: (() -> Any?)! { get nonmutating set }
}

protocol _YObjectProperty {
    var storage: Storage { get }
    var initialValue: () -> Any? { get }
    
    func send(_ value: Any?)
    
    associatedtype Storage: _YObjectPropertyStorage
}

extension YObject {
    @propertyWrapper
    public struct Property<Value: YElement>: _YObjectProperty {
        final class Storage: _YObjectPropertyStorage {
            var setter: ((Any?) -> ())!
            var getter: (() -> Any?)!
            var publisher: CurrentValueSubject<Value, Never>?
        }
        
        public var wrappedValue: Value {
            get { self.storage.publisher?.value ?? Value.fromPersistence(self.storage.getter()) }
            set { self.storage.setter(newValue.persistenceObject()) }
        }
        public var projectedValue: some Publisher<Value, Never> {
            if self.storage.publisher == nil {
                let value = Value.fromPersistence(self.storage.getter())
                self.storage.publisher = CurrentValueSubject(value)
            }
            return self.storage.publisher!
        }
                
        let storage = Storage()
        let initialValue: () -> Any?
        
        public init(wrappedValue: @autoclosure @escaping () -> Value) {
            self.initialValue = { wrappedValue().persistenceObject() }
        }
        
        func send(_ value: Any?) {
            if let publisher = self.storage.publisher {
                publisher.send(Value.fromPersistence(value))
            } else {
                self.storage.publisher = CurrentValueSubject(Value.fromPersistence(value))
            }
        }
    }
}


