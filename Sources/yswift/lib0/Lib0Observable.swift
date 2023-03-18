//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation
import Promise

enum Message {
    case a(Int)
    case b(String)
}

open class Observable_ {
    
}

open class Lib0Observable {
    public struct EventName<Arguments> {
        let name: String
        public init(_ name: String) { self.name = name }
    }
    
    public class Disposer {
        let id = UUID()
    }
    
    private var _observers: [String: [UUID: (Any) throws -> Void]] = [:]
    
    public init() {}
    
    public func isObserving<Args>(_ event: EventName<Args>) -> Bool {
        return self._observers[event.name] != nil
    }

    @discardableResult
    public func on<Args>(_ event: EventName<Args>, _ observer: @escaping (Args) throws -> Void) -> Disposer {
        if (self._observers[event.name] == nil) { self._observers[event.name] = [:] }
        let disposer = Disposer()
        self._observers[event.name]![disposer.id] = { value in
            try observer(value as! Args)
        }
        return disposer
    }
    
    @discardableResult
    public func once<Args>(_ event: EventName<Args>, _ observer: @escaping (Args) throws -> Void) -> Disposer {
        var disposer: Disposer!
        disposer = self.on(event) {
            try observer($0)
            self.off(event, disposer)
        }
        return disposer
    }
    
    public func once<Args>(_ event: EventName<Args>) -> Promise<Args, Never> {
        Promise{ resolve, reject in
            self.once(event, {
                resolve($0)
            })
        }
    }

    public func off<Args>(_ event: EventName<Args>, _ disposer: Disposer) {
        self._observers[event.name]?.removeValue(forKey: disposer.id)
        if self._observers[event.name]?.isEmpty ?? false {
            self._observers.removeValue(forKey: event.name)
        }
    }

    public func emit<Args>(_ event: EventName<Args>, _ args: Args) throws {
        guard let listeners = self._observers[event.name] else { return }
        try listeners.forEach{ try $0.value(args) }
    }
    
    public func destroy() throws {
        self._observers = [:]
    }
}
