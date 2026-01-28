//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 05.01.22.
//

import Foundation

public extension Streams {
    actor RemoveDuplicates<Upstream: Stream>: Stream {
        public var subscriptions: [Weak<Subscription<Upstream.V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstream: Upstream
        var upstreamSubscription: AnySubscription?
        
        let predicate: @Sendable (V, V) async -> Bool
        var recentValue: V?
        
        var bufferedCurrentValue: V?
        
        let debugPrint: Bool
        
        public init(upstream: Upstream, predicate: @escaping @Sendable (V, V) async -> Bool, debugPrint: Bool = false) async {
            self.upstream = upstream
            self.predicate = predicate
            self.debugPrint = debugPrint
            
            bufferedCurrentValue = await upstream.currentValue()
            
            upstreamSubscription = await upstream
                .tap { [weak self] (value: V) in
                    guard let self else { return }
                    
                    guard let recentValue = await self.recentValue else {
                        await self.set(recentValue: value)
                        await self.sendAndUpdateBufferedCurrentValue(value)
                        return
                    }
                    
                    await self.set(recentValue: value)
                    
                    if await !self.predicate(recentValue, value) {
                        await self.sendAndUpdateBufferedCurrentValue(value)
                    }
                }
        }
        
        public func currentValue() async -> Upstream.V? {
            bufferedCurrentValue
        }

        private func set(recentValue: V) {
            self.recentValue = recentValue
        }
        
        private func sendAndUpdateBufferedCurrentValue(_ value: V) async {
            if bufferedCurrentValue != nil {
                bufferedCurrentValue = value
            }
            
            await send(value)
        }
    }
}

public extension Stream {
    func removeDuplicates(by predicate: @escaping @Sendable (V, V) async -> Bool) async
    -> Streams.RemoveDuplicates<Self> {
        await Streams.RemoveDuplicates(upstream: self, predicate: predicate)
    }
}

public extension Stream where V: Equatable {
    func removeDuplicates(debugPrint: Bool = false) async -> Streams.RemoveDuplicates<Self> {
        await Streams.RemoveDuplicates(upstream: self, predicate: { $0 == $1 }, debugPrint: debugPrint)
    }
}

public protocol AsyncEquatable {
    static func == (lhs: Self, rhs: Self) async -> Bool
}

public extension Stream where V: AsyncEquatable {
    func removeDuplicates(debugPrint: Bool = false) async -> Streams.RemoveDuplicates<Self> {
        await Streams.RemoveDuplicates(upstream: self, predicate: { await $0 == $1 }, debugPrint: debugPrint)
    }
}
