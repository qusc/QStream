//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 10.06.24.
//

import Foundation

public extension Streams {
    actor Constant<C: Sendable>: Stream {
        public var subscriptions: [Weak<Subscription<C>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let value: C
        
        public func currentValue() async -> C? {
            value
        }
        
        public init(_ value: C) {
            self.value = value
        }
    }
}

public extension Stream {
    static func constant<C: Sendable>(_ value: C) -> Streams.Constant<C> {
        .init(value)
    }
}

/// Shouldn't type inference work here if we e.g. do `let stream: some Stream<Bool> = .constant(true)`
public extension Stream {
    static func constant(_ value: V) -> Streams.Constant<V> {
        .init(value)
    }
}
