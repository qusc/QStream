//
//  AsyncPipe.swift
//  QStream
//
//  Created by Quirin Schweigert on 29.01.24.
//

/// **Note: Might have overlap with** https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md
/// Consider switching if touching this again.

import Foundation
import Logging

public actor AsyncPipe<Value: Sendable> {
    public enum Error: Swift.Error { case ended }
    public enum SequenceValue: Sendable { case value(Value), end }

    private var bufferedValue: SequenceValue?

    let logger: Logger?

    private let pushLock: AsyncBinarySemaphore = .init()

    private var produceSignal: AsyncBinarySemaphore = .init(value: false)
    private let consumeSignal: AsyncBinarySemaphore = .init(value: false)

    /// Holds the upstream subscription that feeds this pipe, keeping it alive
    /// as long as the pipe exists.
    private var upstreamSubscription: (any AnySubscription)?

    public init(logger: Logger? = .none) { self.logger = logger?.sub() }

    func setUpstreamSubscription(_ subscription: any AnySubscription) {
        self.upstreamSubscription = subscription
    }

    public func push(_ value: SequenceValue) async {
        try? await pushLock.withLockSendableCancelable {
            await pushLocked(value)
        }
    }

    private func pushLocked(_ value: SequenceValue) async {
        assert(bufferedValue == nil)
        bufferedValue = value
        await produceSignal.signal()
        try? await consumeSignal.waitCancelable()
    }


    public func pull() async throws -> SequenceValue {
        try await produceSignal.waitCancelable()
        assert(bufferedValue != nil)
        let value = bufferedValue!
        bufferedValue = nil
        await consumeSignal.signal()
        return value
    }

    public func push(value: Value) async {
        await push(.value(value))
    }

    public func pullValue() async throws -> Value {
        guard case .value(let value) = try await pull() else { throw Error.ended }
        return value
    }
}

public extension AsyncPipe {
    init(
        _ valueType: Value.Type = Value.self,
        bufferingPolicy: AsyncStream<Value>.Continuation.BufferingPolicy = .unbounded,
        _ build: (AsyncStream<Value>.Continuation) -> Void
    ) {
        let asyncStream = AsyncStream<Value>(valueType, bufferingPolicy: bufferingPolicy, build)
        self.init()

        Task { @Sendable [weak self] in
            for await value in asyncStream { await self?.push(value: value) }
            await self?.push(.end)
        }
    }
}

extension AsyncPipe: AsyncSequence {
    public typealias Element = Value

    public struct AsyncIterator: AsyncIteratorProtocol {
        let pipe: AsyncPipe

        public mutating func next() async throws -> Value? {
            switch try await pipe.pull() {
            case .value(let value):
                return value
            case .end:
                return nil
            }
        }
    }

    public nonisolated func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(pipe: self)
    }
}
