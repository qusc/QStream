//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 05.01.22.
//

import Foundation

/// **Warning**: `.compactMap(_:)` can cause the stream to loose its current value, so delivery of the recent "current" value of this stream upon subscription
/// is not guaranteed anymore!
public extension Streams {
    actor CompactMap<Upstream: Stream, V: Sendable>: Stream {
        public var subscriptions: [Weak<Subscription<V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstream: Upstream
        var upstreamSubscription: AnySubscription?
        
        var transform: @Sendable (Upstream.V) async -> V?
        
        /// `.none`: We're not keeping a current value because upstream didn't have one.
        /// `.some(.none)`: We want to keep one but `transform` didn't return a non-nil value to emit downstream yet.
        var bufferedCurrentValue: V??
        
        public func currentValue() async -> V? {
            bufferedCurrentValue.flatMap { $0 }
        }
        
        public init(upstream: Upstream, transform: @escaping @Sendable (Upstream.V) async -> V?) async {
            self.upstream = upstream
            self.transform = transform
            
            upstreamSubscription = await upstream
                .subscribe { [weak self] value in
                    guard let self else { return }
                    guard let transformedValue = await self.transform(value) else { return }
                    
                    /// Update `bufferedCurrentValue` in case we're keeping one
                    if case .some = await self.bufferedCurrentValue {
                        await self.set(bufferedCurrentValue: transformedValue)
                    }
                    
                    await self.send(transformedValue)
                }
            
            if let upstreamCurrentValue = await upstream.currentValue() {
                bufferedCurrentValue = .some(await transform(upstreamCurrentValue))
            }
        }
        
        private func set(bufferedCurrentValue: V?) {
            self.bufferedCurrentValue = bufferedCurrentValue
        }
    }
}

public extension Stream {
    func compactMap<T: Sendable>(_ transform: @escaping @Sendable (V) async -> T?) async -> Streams.CompactMap<Self, T> {
        await Streams.CompactMap(upstream: self, transform: transform)
    }
}

public extension Stream {
    func compactMap<T: Sendable>() async -> Streams.CompactMap<Self, T> where V == T? {
        await Streams.CompactMap(upstream: self, transform: { $0 })
    }
}
