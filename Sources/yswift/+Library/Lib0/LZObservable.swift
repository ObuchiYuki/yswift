//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation
import Combine

public class LZObservable {
    public struct EventName<Arguments> {
        public let name: String
        public init(_ name: String) { self.name = name }
    }
    
    final public class Disposer {
        let id = UUID()
    }
    
    private var _observers: [String: [UUID: (Any) -> Void]] = [:]
    private var _pubilshers: [String: Any] = [:]
    
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
    
    public func publisher<Args>(for event: EventName<Args>) -> some Publisher<Args, Never> {
        if let publisher = self._pubilshers[event.name] {
            return publisher as! PassthroughSubject<Args, Never>
        }
        let publisher = PassthroughSubject<Args, Never>()
        self.on(event) { publisher.send($0) }
        self._pubilshers[event.name] = publisher
        return publisher
    }
    
    @discardableResult
    public func once<Args>(_ event: EventName<Args>, _ observer: @escaping (Args) -> Void) -> Disposer {
        var disposer: Disposer!
        disposer = self.on(event) {
            observer($0)
            self.off(event, disposer)
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
        self._pubilshers = [:]
    }
}

