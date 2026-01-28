//
//  AsyncBinarySemaphore.swift
//  AsyncBinarySemaphore
//
//  Created by Quirin Schweigert on 18.10.21.
//

import Collections
import Foundation

public actor AsyncBinarySemaphore {
    /// Note: doesn't really make sense if used as a signal instead of a lock.
    let allowTaskReentrancy: Bool
    
    /// Note: we do allow this value to take negative values to keep track of re-entrancy w.r.t. a `Task`.
    var value: Int = 1
    
    enum Continuation {
        case nonThrowing(CheckedContinuation<Void, Never>)
        case throwing(CheckedContinuation<Void, Error>)
    }
    
    var waitingContinuations: OrderedDictionary<UUID, Continuation> = [:]

    var owningTask: UnsafeCurrentTask?
    
    var debugDeadlockDetection: Bool
    
    public init(value: Bool = true, allowTaskReentrancy: Bool = false, debugDeadlockDetection: Bool = false) {
        self.value = value ? 1 : 0
        self.allowTaskReentrancy = allowTaskReentrancy
        self.debugDeadlockDetection = debugDeadlockDetection
    }
    
    public func signal() {
        guard value < 1 else { return }

        if withUnsafeCurrentTask(body: { allowTaskReentrancy && $0 == owningTask }) { // TODO: solve dirty fix
            value += 1
        } else {
            value = 1
        }
        
        /// Resume
        if value > 0 {
            if allowTaskReentrancy { // TODO: solve dirty fix
                owningTask = nil
            }
            
            if let waitingContinuation = waitingContinuations.popLast() {
                value -= 1
                waitingContinuation.resume()
            }
        }
    }
    
    public func wait() async {
        if taskCanTakeValue() {
            takeValue()
        } else {
            /// Can't take value immediately, need to suspend. Important: continuation of course needs to be inserted synchronously into
            /// `waitingContinuations`.

            /// Docs: "The body of the closure executes synchronously on the calling task, and once it returns
            /// the calling task is suspended."
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                waitingContinuations.updateValue(.nonThrowing(continuation), forKey: .init(), insertingAt: 0)
            }
            
            if allowTaskReentrancy { // TODO: solve dirty fix
                withUnsafeCurrentTask { currentTask in
                    owningTask = currentTask
                }
            }
        }
    }
    
    public func waitCancelable() async throws {
        guard !Task.isCancelled else { throw CancellationError() } /// Fail early if task is already cancelled, just an optimization.
        
        if taskCanTakeValue() {
            takeValue()
        } else {
            let continuationID: UUID = .init()
            
            /// Can't take value immediately, need to suspend. Important: continuation of course needs to be inserted synchronously into
            /// `waitingContinuations`.
            
            /// `withTaskCancellationHandler` docs: "The `operation` closure executes on the calling execution context, and doesn't
            /// suspend or change execution context unless code contained within the closure
            /// does so. In other words, the potential suspension point of the
            /// `withTaskCancellationHandler(operation:onCancel:)` never suspends by itself before
            /// executing the operation."
            try await withTaskCancellationHandler {
                
                /// `withCheckedThrowingContinuation` docs: "The body of the closure executes synchronously on the calling task, and once it
                /// returns the calling task is suspended."
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    waitingContinuations.updateValue(.throwing(continuation), forKey: continuationID, insertingAt: 0)
                }
                
                /// According to the docs, if the Task was already cancelled when installing the `onCancel` callback, the callback ist called right away,
                /// right before this closure executes. We might still insert the continuation into the list of pending continuations despite the Task being
                /// cancelled already, resulting in the continuation never being resumed. Let's catch this here by checking for Task cancelation after having
                /// inserted the continuation:
                if Task.isCancelled { cancelContinuation(id: continuationID) }
            } onCancel: {
                Task { await cancelContinuation(id: continuationID) }
            }
            
            if allowTaskReentrancy { // TODO: solve dirty fix
                withUnsafeCurrentTask { currentTask in
                    owningTask = currentTask
                }
            }
        }
    }
    
    private func cancelContinuation(id: UUID) {
        guard let continuation = waitingContinuations.removeValue(forKey: id) else { return }
        continuation.cancel()
    }

    private func taskCanTakeValue() -> Bool {
        withUnsafeCurrentTask { currentTask in
            #if DEBUG
            /// NOTE: this won't be able to catch all deadlocks, only the ones where there's only a single task involved.
            if debugDeadlockDetection, !allowTaskReentrancy, currentTask == owningTask {
                fatalError("deadlock detected, current task: \(String(describing: currentTask)), owning task: \(String(describing: owningTask))")
            }
            #endif
            
            /// Allowing reentrancy w.r.t. the current `Task`
            return value > 0 || (allowTaskReentrancy && currentTask == owningTask)
        }
    }
    
    private func takeValue() {
        if allowTaskReentrancy { // TODO: solve dirty fix
            withUnsafeCurrentTask { currentTask in
                value -= 1
                owningTask = currentTask
                
                //            #if DEBUG
                //            if debugDeadlockDetection {
                //                print("deadlock detection: setting current task to \(currentTask)")
                //            }
                //            #endif
            }
        } else {
            value -= 1
        }
    }
}

extension AsyncBinarySemaphore {
    public func withLock<R: Sendable>(_ execute: () async throws -> R) async rethrows -> R {
        await wait()
        defer { signal() }
        return try await execute()
    }
    
    public func withLockSendable<R: Sendable>(_ execute: @Sendable () async throws -> R) async rethrows -> R {
        await wait()
        defer { signal() }
        return try await execute()
    }
    
    public func withLockCancelable<R: Sendable>(_ execute: () async throws -> R) async throws -> R {
        try await waitCancelable()
        defer { signal() }
        return try await execute()
    }
    
    public func withLockSendableCancelable<R: Sendable>(_ execute: @Sendable () async throws -> R) async throws -> R {
        try await waitCancelable()
        defer { signal() }
        return try await execute()
    }
}

extension OrderedDictionary {
    mutating func popLast() -> Value? {
        guard !isEmpty else { return nil }
        return removeLast().value
    }
}

extension AsyncBinarySemaphore.Continuation {
    func resume() {
        switch self {
        case .nonThrowing(let continuation):
            continuation.resume()
            
        case .throwing(let continuation):
            continuation.resume()
        }
    }
    
    func cancel() {
        switch self {
        case .nonThrowing:
            preconditionFailure()
            
        case .throwing(let continuation):
            continuation.resume(throwing: CancellationError())
        }
    }
}
