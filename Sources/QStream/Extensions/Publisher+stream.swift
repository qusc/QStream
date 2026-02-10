//
//  Publisher+stream.swift
//  QStream
//
//  Created by Quirin Schweigert on 10.01.22.
//

#if canImport(Combine)

import Combine
import Foundation
import Logging

private let logger = Logger(label: "QStream.CombineStream")

public extension Streams {
    actor CombineStream<Upstream: Combine.Publisher>: QStream.Stream
    where Upstream.Output: Sendable, Upstream.Failure == Never {
        let debugPrint: Bool

        public var subscriptions: [Weak<QStream.Subscription<Upstream.Output>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()

        var upstreamSubscription: Combine.AnyCancellable?
        var dispatchTask: Task<Void, Never>?

        var currentValue: Upstream.Output?

        public func currentValue() async -> Upstream.Output? {
            currentValue
        }

        public init(upstream: Upstream, priority: TaskPriority? = nil, debugPrint: Bool = false) async {
            self.debugPrint = debugPrint

            var latestValue: V?

            let asyncStream = AsyncStream<V> { continuation in
                /// Important: subscription has to happen synchronously in this initializer in order to determine whether we synchronously receive an initial
                /// value while subscribing. This is the case for Combine publishers that "always have a value" like `CurrentValueSubject`. These we
                /// want to convert into a `QStream.Stream` that also provides a `currentValue` at all times.
                upstreamSubscription = upstream.sink { value in
                    if debugPrint { logger.debug("got value in combine stream: \(value)") }
                    latestValue = value
                    continuation.yield(value)
                }
            }

            /// If we have already synchronously received a value by now we're setting the current value
            currentValue = latestValue

            dispatchTask = Task(priority: priority) { [weak self] in
                for await value in asyncStream {
                    await self?.handle(upstreamValue: value)
                }
            }
        }

        private func set(upstreamSubscription: AnyCancellable?) {
            self.upstreamSubscription = upstreamSubscription
        }

        private func handle(upstreamValue: Upstream.Output) async {
            /// Update current value in value in case we're keeping one
            if case .some = currentValue {
                self.currentValue = upstreamValue
            }

            await send(upstreamValue)
        }

        deinit {
            dispatchTask?.cancel()
        }
    }
}

public extension Publisher where Failure == Never, Output: Sendable {
    func stream(priority: TaskPriority? = nil, debugPrint: Bool = false) async -> Streams.CombineStream<Self> {
        nonisolated(unsafe) let upstream = self
        return await Streams.CombineStream(upstream: upstream, priority: priority, debugPrint: debugPrint)
    }
}

#endif
