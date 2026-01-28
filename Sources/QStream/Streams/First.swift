//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 05.01.22.
//

import Foundation

public extension Streams {
    actor First<Upstream: Stream>: Stream {
        public var subscriptions: [Weak<Subscription<Upstream.V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstream: Upstream
        var upstreamSubscription: AnySubscription?
        var isValueEmitted: Bool = false
        
        /// `.none`: We're not keeping a current value because upstream didn't have one.
        /// `.some(.none)`: We want to keep one but this stream didn't emit a value yet.
        var bufferedCurrentValue: V??
        
        public init(upstream: Upstream) async {
            self.upstream = upstream
            
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
            if !isValueEmitted {
                isValueEmitted = true
                
                /// Update `bufferedCurrentValue` in case we're keeping one
                if case .some = bufferedCurrentValue {
                    bufferedCurrentValue = value
                }
                
                await send(value)
            }
        }
    }
}

public extension Stream {
    func first() async -> Streams.First<Self> {
        await Streams.First(upstream: self)
    }
}
