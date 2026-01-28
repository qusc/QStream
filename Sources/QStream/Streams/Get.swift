//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 05.01.22.
//

import Foundation

public extension Streams {
    actor GetCompactMap<P: Stream, V: Sendable> {
        let upstream: P
        let nextOnly: Bool
        let transform: @Sendable (P.V) async -> V?
        
        var upstreamSubscription: AnySubscription?
        
        var values: [V] = []
        var continuations: [CheckedContinuation<V, Never>] = []
        
        let debugPrint: Bool
        
        init(
            upstream: P,
            transform: @escaping @Sendable (P.V) async -> V?,
            nextOnly: Bool = false,
            debugPrint: Bool = false
        ) {
            self.upstream = upstream
            self.nextOnly = nextOnly
            self.transform = transform
            self.debugPrint = debugPrint
        }
        
        private func ensureSubscription() async {
            if upstreamSubscription == nil {
                if nextOnly {
                    // TODO: shouldn't `await` here before making sure we don't subscribe twice...
                    upstreamSubscription = await upstream.subscribe { [weak self] in await self?.handle(value: $0) }
                } else {
                    upstreamSubscription = await upstream.tap { [weak self] in await self?.handle(value: $0) }
                }
            }
        }
        
        private func handle(value: P.V) async {
            guard let transformed = await transform(value) else { return }
            values.insert(transformed, at: 0)
            continueContinuations()
        }
        
        private func continueContinuations() {
            if !values.isEmpty && !continuations.isEmpty {
                continuations.popLast()!.resume(returning: values.popLast()!)
            }
        }
        
        func get() async -> V {
            await ensureSubscription()
            
            return await withCheckedContinuation {
                continuations.insert($0, at: 0)
                continueContinuations()
            }
        }
        
//        func getCancelable() async throws -> V {
//            await ensureSubscription()
//            
//            let didResume = ManagedAtomic(false)
//            
////            var didResume = false
//            
//            @Sendable func safeResume(_ action: @escaping () -> Void) {
//                if didResume.compareExchange(expected: false, desired: true, ordering: .relaxed).exchanged {
//                    action()
//                }
//            }
//            
//            let throwingContinuationActor: ValueActor<CheckedContinuation<V, Error>?> = .init()
//            
//            return try await withTaskCancellationHandler(operation: {
////                var continuation: CheckedContinuation<V, Error>?
//                
//                return try await withCheckedThrowingContinuation { (throwingContinuation: CheckedContinuation<V, Error>) in
////                    throwingContinuationActor.set(value: throwingContinuation)
//                    Task { await throwingContinuationActor.set(value: throwingContinuation) }
//                    continuations.insert(throwingContinuation, at: 0)
//                    continueContinuations()
////                    continuation = throwingContinuation
//                }
//            }, onCancel: {
//                Task {
//                    let continuation = await throwingContinuationActor.value
//                    
//                    safeResume {
//                        continuation
//                        //                    ?.resume(throwing: CancellationError())
//                    }
//                }
//            })
//
////            return await withCheckedContinuation {
////                continuations.insert($0, at: 0)
////                continueContinuations()
////            }
//        }
    }
}

public extension Stream {
    func get() async -> V {
        await Streams.GetCompactMap(upstream: self, transform: { .some($0) }).get()
    }
    
    func getNext() async -> V {
        await Streams.GetCompactMap(upstream: self, transform: { .some($0) }, nextOnly: true).get()
    }
    
    func get(timeout: DispatchTimeInterval) async throws -> V {
        try await self
            .map { Result<V, Error>.success($0) }
            .merge(Streams.Timer(interval: timeout).map { _ in .failure(CancellationError()) })
            .get() /// `Stream.get()`
            .get() /// `Result<V, Error>.get()`
    }
    
    @available(*, deprecated, message: "Use `getValueCancelable()` instead")
    func getValue<T: Sendable>() async -> T where V == T? {
        await Streams.GetCompactMap(upstream: self, transform: { $0 }).get()
    }
    
    func getValue<T: Sendable>(timeout: DispatchTimeInterval) async throws -> T where V == T? {
        try await self
            .map { $0.map { Result<T, Error>.success($0) } }
            .merge(Streams.Timer(interval: timeout).map { _ in .failure(CancellationError()) })
            .getValue() /// `Stream.getValue()`
            .get() /// `Result<V, Error>.get()`
    }
    
    @available(*, deprecated, message: "Use `getCancelable(timeout:transform:)` instead")
    func getCompactMap<T: Sendable>(
        debugPrint: Bool = false,
        transform: @escaping @Sendable (V) async -> T?
    ) async -> T {
        await Streams.GetCompactMap(upstream: self, transform: transform, debugPrint: debugPrint).get()
    }
    
//    func waitFor(predicate: @escaping @Sendable (V) async -> Bool) async {
//        await getCompactMap { await predicate($0) ? () : nil }
//    }
}
