//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 08.07.24.
//

import Foundation

public extension Task where Success == Never, Failure == Never {
    enum AnyTaskError: Error { case noneSucceeded(errors: [Error]) }
    
    static func any<T: Sendable>(
        of operations: [@Sendable () async throws -> T],
        failImmediately: Bool = false
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            for operation in operations { group.addTask(operation: operation) }

            var errors: [Error] = []
            
            while let result = await group.nextResult() {
                switch result {
                case .success(let value):
                    group.cancelAll()
                    return value
                    
                case .failure(let error):
                    if failImmediately {
                        group.cancelAll()
                        throw error
                    } else {
                        errors.append(error)
                    }
                }
            }

            throw AnyTaskError.noneSucceeded(errors: errors)
        }
    }
    
    static func any<T: Sendable>(
        of operations: [@Sendable () async -> T],
        failImmediately: Bool = false
    ) async -> T? {
        await withTaskGroup(of: T.self) { group in
            for operation in operations { group.addTask(operation: operation) }
            return await group.next()
        }
    }
    
    static func any<T: Sendable>(
        of tasks: [Task<T, Never>],
        failImmediately: Bool = false
    ) async -> T? {
        await any(of: tasks.mapAsync { task in { @Sendable in await task.value } }, failImmediately: failImmediately)
    }
    
    static func any<T: Sendable, E: Error>(
        of tasks: [Task<T, E>],
        failImmediately: Bool = false
    ) async throws -> T {
        try await any(
            of: tasks.mapAsync { task in { @Sendable in try await task.value } },
            failImmediately: failImmediately
        )
    }
}
