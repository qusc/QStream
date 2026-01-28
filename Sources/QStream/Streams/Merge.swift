//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 05.01.22.
//

import Foundation

public extension Streams {
    actor Merge<V: Sendable>: Stream {
        public var subscriptions: [Weak<Subscription<V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        var upstreamSubscriptions: [AnySubscription] = []
        
        var bufferedCurrentValue: V?
        
        public init<A: Stream, B: Stream>(_ a: A, _ b: B) async where A.V == V, B.V == V {
            upstreamSubscriptions = [
                await a.subscribe { [weak self] in await self?.handleUpstreamValue($0) },
                await b.subscribe { [weak self] in await self?.handleUpstreamValue($0) }
            ]
            
            let currentValueA = await a.currentValue()
            let currentValueB = await b.currentValue()
            
            bufferedCurrentValue = currentValueB ?? currentValueA
        }
        
        public init<A: Stream, B: Stream, C: Stream>(_ a: A, _ b: B, _ c: C)
        async where A.V == V, B.V == V, C.V == V {
            upstreamSubscriptions = [
                await a.subscribe { [weak self] in await self?.handleUpstreamValue($0) },
                await b.subscribe { [weak self] in await self?.handleUpstreamValue($0) },
                await c.subscribe { [weak self] in await self?.handleUpstreamValue($0) }
            ]
                        
            let currentValueA = await a.currentValue()
            let currentValueB = await b.currentValue()
            let currentValueC = await c.currentValue()
            
            bufferedCurrentValue = currentValueC ?? currentValueB ?? currentValueA
        }
        
        public init<A: Stream, B: Stream, C: Stream, D: Stream>(_ a: A, _ b: B, _ c: C, _ d: D)
        async where A.V == V, B.V == V, C.V == V, D.V == V {
            upstreamSubscriptions = [
                await a.subscribe { [weak self] in await self?.handleUpstreamValue($0) },
                await b.subscribe { [weak self] in await self?.handleUpstreamValue($0) },
                await c.subscribe { [weak self] in await self?.handleUpstreamValue($0) },
                await d.subscribe { [weak self] in await self?.handleUpstreamValue($0) }
            ]
            
            let currentValueA = await a.currentValue()
            let currentValueB = await b.currentValue()
            let currentValueC = await c.currentValue()
            let currentValueD = await d.currentValue()
            
            bufferedCurrentValue = currentValueD ?? currentValueC ?? currentValueB ?? currentValueA
        }
        
        public init<S: Sequence & Sendable>(_ upstream: S) async where S.Element: Stream, S.Element.V == V {
            upstreamSubscriptions = await upstream.mapAsync {
                await $0.subscribe { [weak self] in await self?.handleUpstreamValue($0) }
            }
            
            bufferedCurrentValue = await upstream.compactMapAsync({ await $0.currentValue() }).last
        }
        
        public init<Upstream: Stream>(_ upstream: Upstream...) async where Upstream.V == V {
            await self.init(upstream)
        }
        
        private func handleUpstreamValue(_ value: V) async {
            /// Update `bufferedCurrentValue` in case we're keeping one
            if case .some = self.bufferedCurrentValue {
                bufferedCurrentValue = value
            }
            
            await self.send(value)
        }
        
        public func currentValue() async -> V? {
            bufferedCurrentValue
        }
        
        func storeUpstreamSubscription(_ upstreamSubscription: AnySubscription) {
            self.upstreamSubscriptions.append(upstreamSubscription)
        }
    }
}

public extension Stream {
    func merge<S: Stream>(_ other: S) async -> Streams.Merge<V> where S.V == V {
        await Streams.Merge(self, other)
    }
}

public extension Sequence where Element: Stream, Self: Sendable {
    func merge() async -> Streams.Merge<Element.V> {
        await Streams.Merge(self)
    }
}
