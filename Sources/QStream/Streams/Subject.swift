//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 04.01.22.
//

import Foundation

public actor Subject<V: Sendable>: Stream {
    let onDeinit: @Sendable () -> Void
    
    public var subscriptions: [Weak<Subscription<V>>] = []
    public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
    
    public private(set) var value: V
    
    public init(value: V, onDeinit: @Sendable @escaping () -> Void = {}) {
        self.value = value
        self.onDeinit = onDeinit
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
        onDeinit()
    }
}

public extension Stream {
    func bind(to value: Subject<V>) async -> Subscription<V> {
        await tap { await value.set($0) }
    }
}

public extension Subject {
    init<Wrapped>() where V == Wrapped? {
        self.init(value: nil)
    }
}
