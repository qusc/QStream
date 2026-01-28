//
//  SyncContinuationSubject.swift
//  QStream
//
//  Created by Quirin Schweigert on 17.07.25.
//

import Foundation

public actor SyncContinuationSubject<V: Sendable>: Stream {
    let onDeinit: @Sendable () -> Void
    
    public var subscriptions: [Weak<Subscription<V>>] = []
    public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
    
    public private(set) var value: V
    
    public nonisolated let continuation: AsyncStream<V>.Continuation
    private let asyncStream: AsyncStream<V>
    private var relayTask: Task<Never, Error>!
    
    public init(value: V, onDeinit: @Sendable @escaping () -> Void = {}) async {
        self.value = value
        self.onDeinit = onDeinit
        
        (asyncStream, continuation) = AsyncStream<V>.makeStream()
        
        relayTask = Task {
            for await value in asyncStream {
                await set(value)
            }
            
            throw CancellationError()
        }
    }
    
    public func currentValue() async -> V? {
        value
    }
    
    public func set(_ value: V) async {
        self.value = value
        await send(value)
    }
    
    public func subscribeUpstreams() async { }
    
    @discardableResult public func mutate<R>(_ body: @Sendable (inout V) throws -> R) async rethrows -> R {
        let returnValue = try body(&value)
        await send(value)
        return returnValue
    }
    
    deinit {
        relayTask.cancel()
        onDeinit()
    }
}

public extension Stream {
    func bind(to value: SyncContinuationSubject<V>) async -> Subscription<V> {
        await tap { await value.set($0) }
    }
}

public extension SyncContinuationSubject {
    init<Wrapped>() async where V == Wrapped? {
        await self.init(value: nil)
    }
}
