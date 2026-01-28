//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 05.01.22.
//

import Foundation

public extension Streams {
    actor DropWhile<Upstream: Stream>: Stream {
        public var subscriptions: [Weak<Subscription<Upstream.V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstream: Upstream
        var upstreamSubscription: AnySubscription?
        var predicate: @Sendable (Upstream.V) -> Bool
        var isDropping: Bool = true
        
        /// `.none`: We're not keeping a current value because upstream didn't have one.
        /// `.some(.none)`: We want to keep one but this stream didn't emit a value yet.
        var bufferedCurrentValue: V??
        
        public init(upstream: Upstream, predicate: @escaping @Sendable (Upstream.V) -> Bool) async {
            self.upstream = upstream
            self.predicate = predicate
            
            upstreamSubscription = await upstream
                .subscribe { [weak self] (value: V) in
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
            if  isDropping, !predicate(value) { isDropping = false }
            guard !isDropping else { return }
            
            /// Update `bufferedCurrentValue` in case we're keeping one
            if case .some = self.bufferedCurrentValue {
                bufferedCurrentValue = value
            }
            
            await send(value)
        }
    }
}

public extension Stream {
    func drop(while predicate: @escaping @Sendable (V) -> Bool) async -> Streams.DropWhile<Self> {
        await Streams.DropWhile(upstream: self, predicate: predicate)
    }
}
