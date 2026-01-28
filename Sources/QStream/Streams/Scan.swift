//
//  Scan.swift
//  
//
//  Created by Quirin Schweigert on 05.01.22.
//

import Foundation

public extension Streams {
    actor Scan<Upstream: Stream, V: Sendable>: Stream {
        public var subscriptions: [Weak<Subscription<V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstream: Upstream
        var upstreamSubscription: AnySubscription?
        
        var nextPartialResult: @Sendable (V, Upstream.V) async -> V
        
        var accumulator: V
        
        /// `.none`: We're not keeping a current value because upstream didn't have one.
        /// `.some(.none)`: We want to keep one but `nextPartialResult` wasn't evaluated yet.
        var bufferedCurrentValue: V??
        
        public func currentValue() async -> V? {
            bufferedCurrentValue.flatMap { $0 }
        }
        
        public init(
            upstream: Upstream,
            initialResult: V,
            nextPartialResult: @escaping @Sendable (V, Upstream.V) async -> V
        ) async {
            self.upstream = upstream
            self.accumulator = initialResult
            self.nextPartialResult = nextPartialResult
            
            if case .none = await upstream.currentValue() {
                bufferedCurrentValue = .none
            } else {
                bufferedCurrentValue = .some(.none)
            }
            
            upstreamSubscription = await upstream
                .tap { [weak self] value in
                    guard let self else { return }
                    
                    let newDownstreamValue = await nextPartialResult(self.accumulator, value)
                    
                    /// Update `bufferedCurrentValue` in case we're keeping one
                    if case .some = await self.bufferedCurrentValue {
                        await self.set(bufferedCurrentValue: newDownstreamValue)
                    }
                    
                    await self.send(newDownstreamValue)
                    await self.set(accumulator: newDownstreamValue)
                }
        }
        
        private func set(accumulator: V) {
            self.accumulator = accumulator
        }
        
        private func set(bufferedCurrentValue: V?) {
            self.bufferedCurrentValue = .some(bufferedCurrentValue)
        }
    }
}

public extension Stream {
    func scan<T: Sendable>(
        initialResult: T,
        _ nextPartialResult: @escaping @Sendable (T, V) async -> T
    ) async -> Streams.Scan<Self, T> {
        await Streams.Scan(upstream: self, initialResult: initialResult, nextPartialResult: nextPartialResult)
    }
}
