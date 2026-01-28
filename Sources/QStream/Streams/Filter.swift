//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 05.01.22.
//

import Foundation

public extension Streams {
    actor Filter<Upstream: Stream>: Stream {
        public var subscriptions: [Weak<Subscription<Upstream.V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstream: Upstream
        var upstreamSubscription: AnySubscription?
        var isIncluded: @Sendable (Upstream.V) async -> Bool
        
        /// `.none`: We're not keeping a current value because upstream didn't have one.
        /// `.some(.none)`: We want to keep one but this stream didn't emit a value yet.
        var bufferedCurrentValue: V??
        
        public init(upstream: Upstream, isIncluded: @escaping @Sendable (Upstream.V) async -> Bool) async {
            self.upstream = upstream
            self.isIncluded = isIncluded
            
            upstreamSubscription = await upstream
                .subscribe { [weak self] value in
                    await self?.handleUpstreamValue(value)
                }
            
            if let upstreamCurrentValue = await upstream.currentValue() {
                bufferedCurrentValue = .some(.none)
                await handleUpstreamValue(upstreamCurrentValue)
            }
        }
        
        public func currentValue() async -> Upstream.V? {
            bufferedCurrentValue.flatMap { $0 }
        }
        
        private func handleUpstreamValue(_ value: Upstream.V) async {
            guard await isIncluded(value) else { return }
            
            /// Update `bufferedCurrentValue` in case we're keeping one
            if case .some = self.bufferedCurrentValue {
                bufferedCurrentValue = value
            }
            
            await self.send(value)
        }
    }
}

public extension Stream {
    func filter(_ isIncluded: @escaping @Sendable (V) async -> Bool) async -> Streams.Filter<Self> {
        await Streams.Filter(upstream: self, isIncluded: isIncluded)
    }
}
