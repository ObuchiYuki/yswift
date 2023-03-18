//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

public class EventHandler<T0, T1> {
    public var handlers: [Disposer: (T0, T1) throws -> Void] = [:]
    
    public typealias Disposer = UUID
    
    public func addListener(_ handler: @escaping (T0, T1) throws -> Void) -> Disposer {
        let disposer = UUID()
        self.handlers[disposer] = handler
        return disposer
    }

    public func removeListener(_ disposer: Disposer) {
        handlers.removeValue(forKey: disposer)
    }

    public func removeAllListeners() {
        self.handlers.removeAll()
    }
    
    public func callListeners(_ v0: T0, _ v1: T1) throws {
        for (_, handler) in self.handlers {
            try handler(v0, v1)
        }
    }
}
