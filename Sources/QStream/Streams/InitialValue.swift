//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 05.01.22.
//

import Foundation

public extension Streams {
    actor InitialValue<Upstream: Stream>: Stream {
        public var subscriptions: [Weak<Subscription<V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstream: Upstream
        var upstreamSubscription: AnySubscription?
                
        var bufferedCurrentValue: V
        
        public init(_ initialValue: Upstream.V, upstream: Upstream) async {
            self.upstream = upstream
            
            bufferedCurrentValue = initialValue

            upstreamSubscription = await upstream
                .subscribe { [weak self] value in
                    guard let self else { return }
                    await self.set(bufferedCurrentValue: value)
                    await self.send(value)
                }
        }
        
        public func currentValue() async -> Upstream.V? {
            bufferedCurrentValue
        }
        
        private func set(bufferedCurrentValue: V) {
            self.bufferedCurrentValue = bufferedCurrentValue
        }
    }
}

public extension Stream {
    func with(initialValue: V) async -> Streams.InitialValue<Self> {
        await Streams.InitialValue(initialValue, upstream: self)
    }
}
