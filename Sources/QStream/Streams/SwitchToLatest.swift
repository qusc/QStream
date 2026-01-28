//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 10.01.22.
//

import Foundation

public extension Streams {
    actor SwitchToLatest<Upstream: Stream, S: Stream>: Stream where Upstream.V == S {
        var keepCurrentValue: Bool = false
        
        public var subscriptions: [Weak<Subscription<S.V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
                
        var upstreamSubscription: AnySubscription?
        var upstreamValueSubscription: AnySubscription?
        
        var bufferedCurrentValue: S.V?
        
        public func currentValue() async -> S.V? {
            bufferedCurrentValue
        }
        
        public init(upstream: Upstream) async {
//            keepCurrentValue = await upstream.currentValue()?.currentValue() != nil

            upstreamSubscription = await upstream
                .tap { [weak self] stream in
//                    Swift.print("SwitchToLatest switching to new stream")
                    await self?.set(keepCurrentValue: upstream.currentValue()?.currentValue() != nil)
                    
                    /// Switch to new stream by subscribing to it and forwarding values to downstream subscribers
                    await self?.set(upstreamValueSubscription: await stream.tap { [weak self] value in
                        guard let self else { return }
                        
                        /// Update `bufferedCurrentValue` in case we're keeping one
                        if await self.keepCurrentValue {
                            await self.set(bufferedCurrentValue: value)
                        }
                        
                        await self.send(value)
                    })
                }
        }
        
        private func set(keepCurrentValue: Bool) {
            self.keepCurrentValue = keepCurrentValue
        }
        
        private func set(bufferedCurrentValue: V?) {
            self.bufferedCurrentValue = bufferedCurrentValue
        }
        
        private func set(upstreamValueSubscription: AnySubscription?) {
            self.upstreamValueSubscription = upstreamValueSubscription
        }
    }
}

public extension Stream where V: Stream {
    func switchToLatest() async -> Streams.SwitchToLatest<Self, V> {
        await Streams.SwitchToLatest(upstream: self)
    }
}
