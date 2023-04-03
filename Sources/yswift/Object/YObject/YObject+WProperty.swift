//
//  File.swift
//  
//
//  Created by yuki on 2023/04/03.
//

import Foundation

extension YObject {
    public func register<T: YWrapperObject>(_ property: WProperty<T>, for key: String) {
        property.storage.getter = {[unowned self] in T.fromPersistence(self._getValue(for: key)) }
        if !YObject.decodingFromContent {
            self._setValue(property.initialValue().opaque, for: key)
        }
    }
}

extension YObject {
    @propertyWrapper
    public struct WProperty<Value: YWrapperObject> {
        final class Storage {
            var _wrappedValue: Value?
            var getter: (() -> Value)!
        }
        
        public var wrappedValue: Value { storage.getter() }
        
        let storage = Storage()
        let initialValue: () -> Value
        
        public init(wrappedValue: @autoclosure @escaping () -> Value) {
            self.initialValue = wrappedValue
        }
    }
}
