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
        self._registerProperty(property, for: key)
    }
    
    public func register<T: YObject>(_ property: Property<YObjectReference<T>>, for key: String) {
        self._registerProperty(property, for: key)
    }
    
    private func _registerProperty<T: YElement>(_ property: Property<T>, for key: String) {
        self._propertyTable[key] = property
        property.storage.setter = {[unowned self] in self._setValue($0.persistenceObject(), for: key) }
        property.storage.getter = {[unowned self] in T.fromPersistence(self._getValue(for: key)) }
        if !YObject.decodingFromContent {
            self._setValue(property.initialValue().persistenceObject(), for: key)
        }
    }
}

protocol _YObjectProperty {
    func send(_ value: Any?)
}

extension YObject {
    @propertyWrapper
    public struct Property<Value: YElement>: _YObjectProperty {
        final class Storage {
            var setter: ((Value) -> ())!
            var getter: (() -> Value)!
            var publisher: CurrentValueSubject<Value, Never>?
        }
        
        public var wrappedValue: Value {
            get { self.storage.publisher?.value ?? self.storage.getter() }
            set { self.storage.setter(newValue) }
        }
        public var projectedValue: some Publisher<Value, Never> {
            if self.storage.publisher == nil {
                self.storage.publisher = CurrentValueSubject(self.storage.getter())
            }
            return self.storage.publisher!
        }
                
        let storage = Storage()
        let initialValue: () -> Value
        
        public init(wrappedValue: @autoclosure @escaping () -> Value) {
            self.initialValue = wrappedValue
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


