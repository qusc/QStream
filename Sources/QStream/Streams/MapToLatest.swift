////
////  File.swift
////
////
////  Created by Quirin Schweigert on 10.01.22.
////
//
//import Foundation
//
//public extension Streams {
//    actor MapToLatest<Upstream: Stream, V: Sendable>: Stream {
//        let keepCurrentValue: Bool
//
//        public var subscriptions: [Weak<Subscription<V>>] = []
//
//        var upstreamSubscription: AnySubscription?
//        var upstreamValueSubscription: AnySubscription?
//
//        var bufferedCurrentValue: V?
//
//        public func currentValue() async -> V? {
//            bufferedCurrentValue
//        }
//
//        public init<S: Stream>(upstream: Upstream, transform: @escaping @Sendable (Upstream.V) async -> S) async
//        where S.V == V {
//            if let currentUpstreamValue = await upstream.currentValue(),
//               await transform(currentUpstreamValue).currentValue() != nil {
//                keepCurrentValue = true
//            } else {
//                keepCurrentValue = false
//            }
//
//            upstreamSubscription = await upstream
//                .tap { [weak self] stream in
//                    /// Switch to new stream by subscribing to it and forwarding values to downstream subscribers
//                    await self?.set(upstreamValueSubscription: await transform(stream).tap { [weak self] value in
//                        guard let self else { return }
//
//                        /// Update `bufferedCurrentValue` in case we're keeping one
//                        if self.keepCurrentValue {
//                            await self.set(bufferedCurrentValue: value)
//                        }
//
//                        await self.send(value)
//                    })
//                }
//        }
//
//        /// Mapping to `Optional<S>`
//        public init<S: Stream>(upstream: Upstream, transform: @escaping @Sendable (Upstream.V) async -> S?) async
//        where S.V == V {
//            if let currentUpstreamValue = await upstream.currentValue(),
//               await transform(currentUpstreamValue)?.currentValue() != nil {
//                keepCurrentValue = true
//            } else {
//                keepCurrentValue = false
//            }
//
//            upstreamSubscription = await upstream
//                .tap { [weak self] stream in
//                    /// Switch to new stream by subscribing to it and forwarding values to downstream subscribers
//                    await self?.set(upstreamValueSubscription: await transform(stream)?.tap { [weak self] value in
//                        guard let self else { return }
//
//                        /// Update `bufferedCurrentValue` in case we're keeping one
//                        if self.keepCurrentValue {
//                            await self.set(bufferedCurrentValue: value)
//                        }
//
//                        await self.send(value)
//                    })
//                }
//        }
//
//
//        private func set(bufferedCurrentValue: V?) {
//            self.bufferedCurrentValue = bufferedCurrentValue
//        }
//
//        private func set(upstreamValueSubscription: AnySubscription?) {
//            self.upstreamValueSubscription = upstreamValueSubscription
//        }
//    }
//}
//
//public extension Stream where V: Stream {
//    func mapToLatest<S: Stream>(transform: @escaping @Sendable (V) async -> S) async
//    -> Streams.MapToLatest<Self, S.V> {
//        await Streams.MapToLatest(upstream: self, transform: transform)
//    }
//
////    func mapToLatest<S: Stream>(transform: @escaping @Sendable (V) async -> S?) async
////    -> Streams.MapToLatest<Self, S.V> {
////        await Streams.MapToLatest(upstream: self, transform: transform)
////    }
//
////    func mapToLatest<S: Stream>(transform: @escaping @Sendable (V) async -> S?) async {
////
////    }
//}
//
