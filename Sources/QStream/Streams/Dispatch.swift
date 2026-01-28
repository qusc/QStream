//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 10.01.22.
//

import Foundation

public extension Streams {
    actor Dispatch<Upstream: Stream>: Stream {
        let upstream: Upstream
        let bufferingPolicy: AsyncStream<V>.Continuation.BufferingPolicy
        
        public var subscriptions: [Weak<Subscription<Upstream.V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        var upstreamSubscription: AnySubscription?
        var bufferedCurrentValue: V?
        var dispatchTask: Task<Void, Never>?
        
        let initSemaphore: AsyncBinarySemaphore = .init(value: false)
        
        public func currentValue() async -> Upstream.V? {
            bufferedCurrentValue
        }
        
        public init(
            upstream: Upstream,
            priority: TaskPriority? = nil,
            bufferingPolicy: AsyncStream<V>.Continuation.BufferingPolicy = .unbounded
        ) async {
            self.upstream = upstream
            self.bufferingPolicy = bufferingPolicy
            
            dispatchTask = Task(priority: priority) { [weak self] in
                let asyncStream = AsyncStream<V>(bufferingPolicy: bufferingPolicy) { continuation in
                    Task(priority: priority) { [weak self] in
                        let subscription = await upstream.subscribe { value in
                            continuation.yield(value)
                        } receiveCurrentValue: { [weak self] in
                            await self?.set(bufferedCurrentValue: $0)
                        }
                        
                        await self?.set(upstreamSubscription: subscription)
                        await self?.initSemaphore.signal()
                    }
                }
                
                for await value in asyncStream {
                    /// Update `bufferedCurrentValue` in case we're keeping one
                    if let self, case .some = await self.bufferedCurrentValue {
                        await self.set(bufferedCurrentValue: value)
                    }
                    
                    await self?.send(value)
                }
            }
            
            /// Wait until upstream subscription is in place and current value is available (if any)
            await initSemaphore.wait()
        }
        
        private func set(bufferedCurrentValue: V?) {
            self.bufferedCurrentValue = bufferedCurrentValue
        }
        
        private func set(upstreamSubscription: AnySubscription?) {
            self.upstreamSubscription = upstreamSubscription
        }
        
        deinit {
            dispatchTask?.cancel()
        }
    }
}

public extension Stream {
    func dispatch(
        priority: TaskPriority? = nil,
        bufferingPolicy: AsyncStream<V>.Continuation.BufferingPolicy = .unbounded
    ) async -> Streams.Dispatch<Self> {
        await Streams.Dispatch(upstream: self, priority: priority, bufferingPolicy: bufferingPolicy)
    }
}

extension AsyncStream.Continuation.BufferingPolicy: @unchecked Sendable { }
