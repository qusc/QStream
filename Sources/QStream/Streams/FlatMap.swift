//
//  FlatMap.swift
//  
//
//  Created by Quirin Schweigert on 27.07.22.
//

import Foundation

public extension Streams {
    actor FlatMap<Upstream: Stream, V: Sendable>: Stream {
        public var subscriptions: [Weak<Subscription<V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstream: Upstream
        var upstreamSubscription: AnySubscription?
        
        var transform: @Sendable (Upstream.V) async -> [V]
        
        public func currentValue() async -> V? {
            nil
        }
        
        public init(upstream: Upstream, transform: @escaping @Sendable (Upstream.V) async -> [V]) async {
            self.upstream = upstream
            self.transform = transform
            
            upstreamSubscription = await upstream
                .subscribe { [weak self] value in
                    let transformedValues = await self?.transform(value)
                    await transformedValues?.forEachAsync { [weak self] in await self?.send($0) }
                }
        }
    }
}

public extension Stream {
    func flatMap<T: Sendable>(_ transform: @escaping @Sendable (V) async -> [T]) async -> Streams.FlatMap<Self, T> {
        await Streams.FlatMap(upstream: self, transform: transform)
    }
    
    func flatMap<T: Sendable>() async -> Streams.FlatMap<Self, T> where V == [T] {
        await flatMap { $0 }
    }
}

