//
//  Future.swift
//  DebugPlayer
//
//  Created by Quirin Schweigert on 01.03.23.
//

import Foundation

public struct Future<Value: Sendable>: Sendable {
    let task: Task<Value, Never>

    public init(_ execute: @Sendable @escaping () async -> Value) {
        task = .init(operation: execute)
    }
    
    public init(task: Task<Value, Never>) {
        self.task = task
    }

    public var value: Value {
        get async {
            await task.value
        }
    }
    
    public func stream() async -> AnyStream<Value?> {
        let subject: Subject<Value?> = .init()
        Task { await subject.set(task.value) }
        return await subject.any()
    }
    
    public func stream<V>() async -> AnyStream<V?> where Value == V? {
        let subject: Subject<V?> = .init()
        Task { await subject.set(task.value) }
        return await subject.any()
    }
}

public extension Stream {
    func mapToFuture<T: Sendable>(_ transform: @escaping @Sendable (V) async -> T?) async -> AnyStream<T?> {
        await self
            .map { v in await Future<T?>({ await transform(v) }).stream() }
            .switchToLatest()
            .any()
    }
}
