//
//  GroupByEvent.swift
//  CoreUtil
//
//  Created by yuki on 2021/09/25.
//  Copyright © 2021 yuki. All rights reserved.
//

import Combine

extension Publisher {
    @inlinable public func grouping(by session: GroupingSession) -> Publishers.Grouping<Self> {
        Publishers.Grouping(upstream: self, session: session)
    }
}

public class GroupingSession {
    
    @inlinable static public func publish() -> GroupingSession { GroupingSession() }
    
    @usableFromInline init() {}
        
    public var isGrouping: Bool { groupingCounter > 0 }
    
    @usableFromInline var groupingCounter = 0
    @usableFromInline var handlers = [() -> ()]()
    
    @inlinable public func start() {
        self.groupingCounter += 1
    }
    
    @inlinable public func commit() {
        self.groupingCounter -= 1
        assert(self.groupingCounter >= 0, "Session corrupted.")
        guard !isGrouping else { return }
        for handler in self.handlers { handler() }
        self.handlers = []
    }
    
    @inlinable public func execute(_ body: @escaping () -> ()) {
        if self.isGrouping {
            self.handlers.append(body)
        }else{
            body()
        }
    }
}

extension GroupingSession: CustomStringConvertible {
    public var description: String {
        "GroupingSession(isGrouping: \(isGrouping))"
    }
}

extension Publishers {
    public struct Grouping<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        
        public let session: GroupingSession
        public let upstream: Upstream
        
        @inlinable public init(upstream: Upstream, session: GroupingSession) {
            self.upstream = upstream
            self.session = session
        }
        
        @inlinable public func receive<Downstream>(subscriber downstream: Downstream)
            where Downstream : Subscriber, Self.Failure == Downstream.Failure, Self.Output == Downstream.Input
        {
            self.upstream.subscribe(Inner(downstream: downstream, session: session))
        }
    }
}

extension Publishers.Grouping {
    final public class Inner<Downstream: Subscriber>: Subscriber where Downstream.Input == Output, Downstream.Failure == Upstream.Failure {
        
        public typealias Input = Upstream.Output
        public typealias Failure = Upstream.Failure
        
        public let downstream: Downstream
        public let session: GroupingSession
        @usableFromInline var isGrouping = false
        @usableFromInline var currentInput: Input?
        
        @inlinable init(downstream: Downstream, session: GroupingSession) {
            self.downstream = downstream
            self.session = session
        }

        @inlinable public func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }

        @inlinable public func receive(_ input: Input) -> Subscribers.Demand {
            self.currentInput = input

            if self.isGrouping { return .unlimited }; self.isGrouping = true

            self.session.execute {
                self.isGrouping = false
                if let currentInput = self.currentInput { _ = self.downstream.receive(currentInput) }
            }
            
            return .unlimited
        }

        @inlinable public func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }
    }
}
