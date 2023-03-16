//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

open class Lib0Observable {
    public struct EventName<Arguments> {
        let name: String
        public init(_ name: String) { self.name = name }
    }
    
    public class Disposer {
        let id = UUID()
    }
    
    private var _observers: [String: [UUID: (Any) -> Void]] = [:]
    
    public init() {}
    
    public func isObserving<Args>(_ event: EventName<Args>) -> Bool {
        return self._observers[event.name] != nil
    }

    @discardableResult
    public func on<Args>(_ event: EventName<Args>, _ observer: @escaping (Args) -> Void) -> Disposer {
        if (self._observers[event.name] == nil) { self._observers[event.name] = [:] }
        let disposer = Disposer()
        self._observers[event.name]![disposer.id] = { value in
            observer(value as! Args)
        }
        return disposer
    }

    public func off<Args>(_ event: EventName<Args>, _ disposer: Disposer) {
        self._observers[event.name]?.removeValue(forKey: disposer.id)
        if self._observers[event.name]?.isEmpty ?? false {
            self._observers.removeValue(forKey: event.name)
        }
    }

    public func emit<Args>(_ event: EventName<Args>, _ args: Args) {
        guard let listeners = self._observers[event.name] else { return }
        listeners.forEach{ $0.value(args) }
    }
    
    public func destroy() {
        self._observers = [:]
    }
}
