//
//  AsyncSequenceStream.swift
//  QStream
//
//  Created by Quirin Schweigert on 03.11.25.
//

import Foundation

@available(watchOS 11.0, iOS 18.0, *)
public actor AsyncSequenceStream<V: Sendable>: Stream {
    let onDeinit: @Sendable () -> Void
    
    public var subscriptions: [Weak<Subscription<V>>] = []
    public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
    
    public private(set) var value: V?
    
    private let upstream: any AsyncSequence<V, Never>
    
    private var relayTask: Task<Void, Error>!
    
    public init(_ upstream: any AsyncSequence<V, Never>, onDeinit: @Sendable @escaping () -> Void = {}) async {
        self.upstream = upstream
        self.onDeinit = onDeinit
        
        relayTask = Task {
            for try await upstreamValue in upstream {
                await set(upstreamValue)
            }
        }
    }
    
    private func set(_ value: V) async {
        self.value = value
        await send(value)
    }
    
    public func currentValue() async -> V? {
        value
    }
    
    deinit {
        relayTask.cancel()
        onDeinit()
    }
}
