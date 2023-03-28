//
//  File.swift
//  
//
//  Created by yuki on 2023/03/28.
//

import Combine

protocol YObjectProperty {
    func send(_ value: Any?)
}

extension YObject {
    @propertyWrapper
    public struct Property<Value>: YObjectProperty {
        final class Storage {
            var setter: ((Value) -> ())? = nil
            var getter: (() -> (Value))? = nil
            var receivedValue = false
        }
        
        public var wrappedValue: Value {
            get { self.storage.receivedValue ? publisher.value : self.storage.getter!() }
            set { self.storage.setter!(newValue) }
        }
        public var projectedValue: some Publisher<Value, Never> {
            if !self.storage.receivedValue { publisher.send(self.storage.getter!()) }
            return publisher
        }
        
        private let publisher: CurrentValueSubject<Value, Never>
        
        let storage = Storage()
        
        func send(_ value: Any?) {
            self.publisher.send(value as! Value)
            self.storage.receivedValue = true
        }
        
        public init(wrappedValue: Value) {
            self.publisher = CurrentValueSubject(wrappedValue)
        }
    }
}
