//
//  GetCancelable.swift
//  QStream
//
//  Created by Quirin Schweigert on 16.01.25.
//

extension Streams {
    fileprivate actor GetCancelableState<U: Stream, T: Sendable> {
        let upstream: U
        let transform: @Sendable (U.V) async -> T?
        
        var upstreamSubscription: AnySubscription?
        var continuation: CheckedContinuation<T, any Error>?
        
        var isResumed: Bool = false
        var isCancelled: Bool = false
        
        init(
            upstream: U,
            transform: @escaping @Sendable (U.V) async -> T?
        ) {
            self.upstream = upstream
            self.transform = transform
        }
        
        func provideContinuation(_ continuation: CheckedContinuation<T, any Error>) async {
            guard !isCancelled else {
                isResumed = true
                continuation.resume(throwing: CancellationError())
                return
            }
            
            self.continuation = continuation
            
            upstreamSubscription = await upstream.tap { [weak self] value in
                if let transformed = await self?.transform(value) {
                    await self?.onReceive(value: transformed)
                }
            }
        }
        
        func onReceive(value: T) {
            guard !isResumed, !isCancelled else { return }
            
            /// Note: invariant: `continuation` has been provided (we only subscribe to `upstream` once we receive the continuation)
            guard let continuation else { fatalError("continuation hasn't been provided yet") }
            
            isResumed = true
            continuation.resume(returning: value)
            upstreamSubscription = nil
        }
        
        func onCancel() {
            guard !isResumed, !isCancelled else { return }
            
            isCancelled = true
            isResumed = true
            continuation?.resume(throwing: CancellationError()) /// Note: `continuation` might not have been provided yet.
            upstreamSubscription = nil
        }
    }
}

extension Stream {
    public func getCancelable<T: Sendable>(
        timeout: ContinuousClock.Duration?,
        transform: @escaping @Sendable (V) async -> T?
    ) async throws -> T {
        if let timeout {
            try await withTimeout(timeout) { [self] in try await self.getCancelable(transform: transform) }
        } else {
            try await self.getCancelable(transform: transform)
        }
    }
    
    public func getCancelable<T: Sendable>(
        transform: @escaping @Sendable (V) async -> T?
    ) async throws -> T {
        let state: Streams.GetCancelableState = .init(upstream: self, transform: transform)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Task { await state.provideContinuation(continuation) }
            }
        } onCancel: {
            Task { await state.onCancel() }
        }
    }
    
    public func getCancelable<T: Sendable>(
        timeout: ContinuousClock.Duration,
        transform: @escaping @Sendable (V) async -> T?
    ) async throws -> T where V == T? {
        return try await withTimeout(timeout) { [self] in try await getCancelable { $0 } }
    }
    
    public func getValueCancelable<T: Sendable>() async throws -> T where V == T? {
        try await getCancelable { $0 }
    }
    
    public func getValueCancelable<T: Sendable>(
        timeout: ContinuousClock.Duration,
        file: @autoclosure () -> String = #file,
        line: @autoclosure () -> Int = #line
    ) async throws -> T where V == T? {
        let file = file()
        let line = line()
        return try await withTimeout(timeout, file: file, line: line) { [self] in try await getCancelable { $0 } }
    }
    
    public func waitFor(predicate: @escaping @Sendable (V) async -> Bool) async throws {
        try await getCancelable { await predicate($0) ? () : nil }
    }
}
