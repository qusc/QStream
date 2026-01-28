//
//  AnyStream.swift
//  
//
//  Created by Quirin Schweigert on 05.01.22.
//

import Foundation

public actor AnyStream<V: Sendable>: Stream {
    public var subscriptions: [Weak<Subscription<V>>] = []
    public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
    
    var upstreamSubscription: AnySubscription?
    
    let getCurrentWrappedValue: @Sendable () async -> V?
    
    init<S: Stream>(wrapped: S) async where S.V == V {
        getCurrentWrappedValue = { await wrapped.currentValue() }
        upstreamSubscription = await wrapped.subscribe { [weak self] in await self?.send($0) }
    }
    
    public func currentValue() async -> V? {
        await getCurrentWrappedValue()
    }
}

public extension Stream {
    func any() async -> AnyStream<V> {
        await .init(wrapped: self)
    }
}
