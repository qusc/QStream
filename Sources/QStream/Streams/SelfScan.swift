//
//  SelfScan.swift
//  
//
//  Created by Quirin Schweigert on 06.04.22.
//

import Foundation

public extension Streams {
    actor SelfScan<Upstream: Stream, V: Sendable>: Stream {
        public var subscriptions: [Weak<Subscription<V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstream: Upstream
        var upstreamSubscription: AnySubscription?
        
        var nextPartialResult: @Sendable (Upstream.V?, Upstream.V) async -> V
        
        var lastValue: Upstream.V?
        
        /// `.none`: We're not keeping a current value because upstream didn't have one.
        /// `.some(.none)`: We want to keep one but `nextPartialResult` wasn't evaluated yet.
        var bufferedCurrentValue: V??
        
        public func currentValue() async -> V? {
            bufferedCurrentValue.flatMap { $0 }
        }
        
        public init(
            upstream: Upstream,
            nextPartialResult: @escaping @Sendable (Upstream.V?, Upstream.V) async -> V
        ) async {
            self.upstream = upstream
            self.nextPartialResult = nextPartialResult
            
            if case .none = await upstream.currentValue() {
                bufferedCurrentValue = .none
            } else {
                bufferedCurrentValue = .some(.none)
            }
            
            upstreamSubscription = await upstream
                .tap { [weak self] value in
                    guard let self else { return }
                    
                    let newDownstreamValue = await nextPartialResult(self.lastValue, value)
                    
                    /// Update `bufferedCurrentValue` in case we're keeping one
                    if case .some = await self.bufferedCurrentValue {
                        await self.set(bufferedCurrentValue: newDownstreamValue)
                    }
                    
                    await self.send(newDownstreamValue)
                    
                    await self.set(lastValue: value)
                }
        }
        
        private func set(lastValue: Upstream.V?) {
            self.lastValue = lastValue
        }
        
        private func set(bufferedCurrentValue: V?) {
            self.bufferedCurrentValue = .some(bufferedCurrentValue)
        }
    }
}

public extension Stream {
    func selfScan<T: Sendable>(_ nextPartialResult: @escaping @Sendable (V?, V) async -> T)
    async -> Streams.SelfScan<Self, T> {
        await Streams.SelfScan(upstream: self, nextPartialResult: nextPartialResult)
    }
}
