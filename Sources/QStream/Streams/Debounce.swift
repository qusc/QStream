//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 05.01.22.
//

import Foundation

public extension Streams {
    actor Debounce<Upstream: Stream>: Stream {
        public var subscriptions: [Weak<Subscription<Upstream.V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstream: Upstream
        var upstreamSubscription: AnySubscription?
        
        let debounceInterval: DispatchTimeInterval
        
        var earliestEmitTime: DispatchTime?
        var bufferedValue: V?
        
        /// `.none`: We're not keeping a current value because upstream didn't have one.
        /// `.some(.none)`: We want to keep one but this stream didn't emit a value yet.
        var bufferedCurrentValue: V??
        
        var emitTask: Task<Void, Never>?
        
        public init(_ upstream: Upstream, for debounceInterval: DispatchTimeInterval) async {
            self.upstream = upstream
            self.debounceInterval = debounceInterval
            
            upstreamSubscription = await upstream
                .tap { [weak self] value in await self?.onReceiveUpstream(value: value) }
            
            if await upstream.currentValue() != nil {
                bufferedCurrentValue = .some(.none)
            }
        }
        
        public func currentValue() async -> Upstream.V? {
            bufferedCurrentValue.flatMap { $0 }
        }
        
        private func onReceiveUpstream(value: V) {
            self.bufferedValue = value
            self.earliestEmitTime = .now().advanced(by: debounceInterval)
            if emitTask == nil { createEmitTask() }
        }
        
        private func clearEmitTask() { self.emitTask = nil }
        
        private func createEmitTask() {
            emitTask = Task { [weak self] in
                if let earliestEmitTime = await self?.earliestEmitTime {
                    try? await Task.sleep(until: earliestEmitTime)
                } else {
                    return
                }
                
                /// `earliestEmitTime` could have changed in the meantime so we need to change whether we need to sleep again
                guard let earliestEmitTime = await self?.earliestEmitTime, earliestEmitTime <= .now() else {
                    await self?.createEmitTask()
                    return
                }
                
                guard let bufferedValue = await self?.bufferedValue else { return }
                
                if let self, case .some = await self.bufferedCurrentValue {
                    await self.set(bufferedCurrentValue: bufferedValue)
                }
                
                await self?.send(bufferedValue)
                await self?.clearEmitTask()
            }
        }
        
        private func set(bufferedCurrentValue: V?) {
            self.bufferedCurrentValue = bufferedCurrentValue
        }
    }
}

public extension Stream {
    func debounce(for debounceInterval: DispatchTimeInterval) async -> Streams.Debounce<Self> {
        await Streams.Debounce(self, for: debounceInterval)
    }
}
