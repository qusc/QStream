//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 05.01.22.
//

import Foundation

public extension Streams {
    actor Throttle<Upstream: Stream>: Stream {
        public var subscriptions: [Weak<Subscription<Upstream.V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstream: Upstream
        var upstreamSubscription: AnySubscription?
        
        let throttleInterval: DispatchTimeInterval
        let emitImmediately: Bool
        
        var lastEmitTime: DispatchTime?
        var pendingValue: V?
        
        /// `.none`: We're not keeping a current value because upstream didn't have one.
        /// `.some(.none)`: We want to keep one but this stream didn't emit a value yet.
        var bufferedCurrentValue: V??
        
        var emitTask: Task<Void, Never>?
        
        let debugPrint: Bool
        
        public init(
            _ upstream: Upstream,
            throttleInterval: DispatchTimeInterval,
            emitImmediately: Bool = true,
            debugPrint: Bool = false
        ) async {
            self.upstream = upstream
            self.throttleInterval = throttleInterval
            self.emitImmediately = emitImmediately
            self.debugPrint = debugPrint
            
            if await upstream.currentValue() != nil {
                bufferedCurrentValue = .some(.none)
            }
            
            await subscribeUpstreams()
        }
        
        public func currentValue() async -> Upstream.V? {
            bufferedCurrentValue.flatMap { $0 }
        }
        
        private func subscribeUpstreams() async {
            guard upstreamSubscription == nil else { return }
            upstreamSubscription = await upstream.tap { [weak self] value in await self?.onReceiveUpstream(value: value) }
        }
        
        private func onReceiveUpstream(value: V) async {
            if emitImmediately,
               lastEmitTime == nil || lastEmitTime!.distance(to: .now()) >= throttleInterval,
               emitTask == nil {
                /// Value can be emitted immediately
                await emit(value)
            } else {
                self.pendingValue = value
                if emitTask == nil { schedulePendingEmit() }
            }
        }
        
        private func clearEmitTask() { self.emitTask = nil }
        
        private func schedulePendingEmit() {
            emitTask = Task { [weak self] in
                guard let throttleInterval = self?.throttleInterval else { return }
                
                /// Need to wait for remaining interval of `throttleInterval`
                let timeSinceLastEmit = await self?.lastEmitTime.map { $0.distance(to: .now()).totalNanoseconds } ?? 0
                let sleepTime = throttleInterval.totalNanoseconds - timeSinceLastEmit
                
                if sleepTime >= 0 {
                    try? await Task.sleep(nanoseconds: UInt64(sleepTime))
                }
                
                guard let pendingValue = await self?.pendingValue else { return }
                
                await self?.emit(pendingValue)
                await self?.clearEmitTask()
            }
        }
        
        private func emit(_ value: V) async {
            lastEmitTime = .now()
            
            if bufferedCurrentValue != nil {
                bufferedCurrentValue = value
            }
            
            await send(value)
        }
        
        public func waitForPendingEmit() async {
            await emitTask?.value
        }
    }
}

public extension Stream {
    func throttle(
        for interval: DispatchTimeInterval,
        emitImmediately: Bool = true,
        debugPrint: Bool = false
    ) async -> Streams.Throttle<Self> {
        await Streams.Throttle(
            self,
            throttleInterval: interval,
            emitImmediately: emitImmediately,
            debugPrint: debugPrint
        )
    }
}
