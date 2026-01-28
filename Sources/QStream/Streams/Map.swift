//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 04.01.22.
//

import Foundation

public extension Streams {
    actor Map<Upstream: Stream, V: Sendable>: Stream {
        public var subscriptions: [Weak<Subscription<V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstream: Upstream
        var upstreamSubscription: AnySubscription?
        
        var transform: @Sendable (Upstream.V) async -> V
        
        var bufferedCurrentValue: V?
        
        public func currentValue() async -> V? {
            bufferedCurrentValue
        }
        
        public init(upstream: Upstream, transform: @escaping @Sendable (Upstream.V) async -> V) async {
            self.upstream = upstream
            self.transform = transform
            
            upstreamSubscription = await upstream
                .subscribe { [weak self] value in
                    guard let self else { return }
                    let transformedValue = await self.transform(value)
                    
                    /// Update `bufferedCurrentValue` in case we're keeping one
                    if case .some = await self.bufferedCurrentValue {
                        await self.set(bufferedCurrentValue: transformedValue)
                    }
                    
                    await self.send(transformedValue)
                }
            
            if let upstreamCurrentValue = await upstream.currentValue() {
                bufferedCurrentValue = await transform(upstreamCurrentValue)
            }
        }
        
        private func set(bufferedCurrentValue: V?) {
            self.bufferedCurrentValue = bufferedCurrentValue
        }
    }
}

public extension Stream {
    func map<T: Sendable>(_ transform: @escaping @Sendable (V) async -> T) async -> Streams.Map<Self, T> {
        await Streams.Map(upstream: self, transform: transform)
    }
}
