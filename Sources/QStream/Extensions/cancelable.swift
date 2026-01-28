//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 03.07.24.
//

import Foundation

/// **Note: this whole thing is highly problematic as it is likely to leak memory: The `Task` stack belonging to the child task might not finish executing
/// and might not deallocate (and objects it references)**

actor CancelableWrapperState<V: Sendable/* & Escapable*/> {
    var continuation: CheckedContinuation<V, Error>?
    var isResumed: Bool = false
    var isCancelled: Bool = false
    var operationTask: Task<Void, Never>?

    func provideContinuation(_ continuation: CheckedContinuation<V, Error>) {
        guard !isCancelled else {
            isResumed = true
            continuation.resume(throwing: CancellationError())
            return
        }
        
        self.continuation = continuation
    }
    
    func onResult(_ result: Result<V, Error>) {
        guard !isResumed, !isCancelled else { return }
        guard let continuation else { fatalError("continuation hasn't been provided yet") }

        isResumed = true
        continuation.resume(with: result) // Result conforms to Sendable: when Success conforms to Escapable, Success conforms to Sendable, and Failure conforms to Error.
    }
    
    func onCancel() {
        isCancelled = true
        guard !isResumed else { return }
        isResumed = true
        continuation?.resume(throwing: CancellationError())
        operationTask?.cancel()
    }
    
    func storeOperationTask(_ task: Task<Void, Never>) {
        operationTask = task
        if isCancelled { task.cancel() }
    }
}

/// WARNING: this breaks the usual guarantee that the child tasks finished execution when they return or throw. This does cancel the child task though if the
/// current task of the calling code is cancelled.
public func cancelable<V: Sendable>(_ operation: @Sendable @escaping () async throws -> V) async throws -> V {
    let state: CancelableWrapperState<V> = .init()
    
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            let operationTask = Task {
                await state.provideContinuation(continuation)
                let result: Result<V, Error> = await .init(catching: operation)
                await state.onResult(result)
            }
            
            Task {
                await state.storeOperationTask(operationTask)
            }
        }
    } onCancel: {
        Task { await state.onCancel() }
    }
}
