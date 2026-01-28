//
//  Hold.swift
//  
//
//  Created by Quirin Schweigert on 22.10.22.
//

import Foundation

public extension Streams {
    actor Hold<Upstream: Stream>: Stream where Upstream.V == Bool {
        public var subscriptions: [Weak<Subscription<Bool>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstream: Upstream
        var upstreamSubscription: AnySubscription?
        
        let holdInterval: DispatchTimeInterval

        /// Always buffering a value
        var bufferedCurrentValue: V?
        
        var emitTask: Task<Void, Error>?
        var semaphore: AsyncBinarySemaphore = .init()
        
        let debugPrint: Bool
        
        public init(
            _ upstream: Upstream,
            holdInterval: DispatchTimeInterval,
            debugPrint: Bool = false
        ) async {
            self.upstream = upstream
            self.holdInterval = holdInterval
            self.debugPrint = debugPrint
            await subscribeUpstreams()
        }
        
        public func currentValue() async -> Upstream.V? {
            bufferedCurrentValue.flatMap { $0 }
        }
        
        private func subscribeUpstreams() async {
            guard upstreamSubscription == nil else { return }
            upstreamSubscription = await upstream
                .tap { [weak self] value in await self?.onReceiveUpstream(value: value) }
        }
        
        private func onReceiveUpstream(value: V) async {
            await semaphore.wait()
            
            if value {
                emitTask?.cancel()
                emitTask = nil
                await emit(true)
            } else {
                if bufferedCurrentValue == true {
                    if emitTask == nil {
                        schedulePendingEmit()
                    }
                } else {
                    await emit(false)
                }
            }
            
            await semaphore.signal()
        }
        
        private func clearEmitTask() { self.emitTask = nil }
        
        private func schedulePendingEmit() {
            emitTask = Task { [weak self] in
                guard let holdInterval = self?.holdInterval else { return }

                try await Task.sleep(timeInterval: holdInterval)

                await self?.semaphore.wait()
                await self?.emit(false)
                await self?.clearEmitTask()
                await self?.semaphore.signal()
            }
        }
        
        private func emit(_ value: V) async {
            bufferedCurrentValue = value
            await send(value)
        }
    }
}

public extension Stream where V == Bool {
    func hold(
        for interval: DispatchTimeInterval,
        debugPrint: Bool = false
    ) async -> Streams.Hold<Self> {
        await Streams.Hold(
            self,
            holdInterval: interval,
            debugPrint: debugPrint
        )
    }
}
