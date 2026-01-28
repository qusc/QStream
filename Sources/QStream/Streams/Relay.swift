//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 04.01.22.
//

import Foundation

public actor Relay<V: Sendable>: Stream {
    public var subscriptions: [Weak<Subscription<V>>] = []
    public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
    
    public init() { }
    
    public func currentValue() async -> V? {
        nil
    }
}

public extension Stream {
    func bind(to relay: Relay<V>) async -> Subscription<V> {
        await tap { await relay.send($0) }
    }
}
