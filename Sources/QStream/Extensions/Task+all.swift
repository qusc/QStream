//
//  Task+all.swift
//  QStream
//
//  Created by Quirin Schweigert on 05.02.25.
//

import Foundation

public extension Task where Success == Never, Failure == Never {
    enum AllTaskError: Error { case someFailed(errors: [Error]) }

    static func all<T: Sendable>(
        of operations: [@Sendable () async throws -> T]
    ) async throws -> [T] {
        try await withThrowingTaskGroup(of: T.self) { group in
            for operation in operations { group.addTask(operation: operation) }

            var results: [T] = []
            var errors: [Error] = []

            while let result = await group.nextResult() {
                switch result {
                case .success(let value):
                    results.append(value)
                case .failure(let error):
                    errors.append(error)
                }
            }

            if errors.isEmpty {
                return results
            } else {
                throw AllTaskError.someFailed(errors: errors)
            }
        }
    }
    
    static func all(
        of operations: [@Sendable () async throws -> Void]
    ) async throws {
        let _: [Void] = try await all(of: operations)
    }
}
