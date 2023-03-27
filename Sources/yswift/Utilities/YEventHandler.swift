//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation
import Combine

final class YEventHandler<Args> {
    private var handlers: [Disposer: (Args) throws -> Void] = [:]
    
    typealias Disposer = UUID
    
    func addListener(_ handler: @escaping (Args) throws -> Void) -> Disposer {
        let disposer = UUID()
        self.handlers[disposer] = handler
        return disposer
    }

    func removeListener(_ disposer: Disposer) {
        handlers.removeValue(forKey: disposer)
    }

    func removeAllListeners() {
        self.handlers.removeAll()
    }
    
    func callListeners(_ args: Args) throws {
        for (_, handler) in self.handlers { try handler(args) }
    }
    
    public private(set) lazy var publisher: some Combine.Publisher<Args, Never> = {
        let publisher = PassthroughSubject<Args, Never>()
        _ = self.addListener({ publisher.send($0) })
        return publisher
    }()
}
