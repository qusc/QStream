//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 11.04.24.
//

import Foundation

public struct TimeoutError: Error {
    let file: String
    let line: Int
}

@discardableResult
public func withTimeout<T: Sendable>(
    _ interval: ContinuousClock.Duration,
    file: @autoclosure () -> String = #file,
    line: @autoclosure () -> Int = #line,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    let file = file()
    let line = line()
    
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }

        group.addTask {
            try await Task.sleep(for: interval)
            throw TimeoutError(file: file, line: line)
        }
        
        if let result = try await group.next() {
            /// Important: need to cancel all other tasks (the throwing one in this case), group waits for all tasks to be complete otherwise, even if we have
            /// already returned the final value.
            group.cancelAll()
            return result
        } else {
            throw CancellationError()
        }
    }
}
