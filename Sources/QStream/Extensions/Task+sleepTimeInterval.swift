//
//  File.swift
//  File
//
//  Created by Quirin Schweigert on 15.09.21.
//

import Foundation

public extension Task where Failure == Never, Success == Never {
    static func sleep(timeInterval: TimeInterval) async throws {
        try await sleep(nanoseconds: UInt64(timeInterval * 1_000_000_000))
    }
}

public extension Task where Failure == Never, Success == Never {
    static func sleep(timeInterval: DispatchTimeInterval) async throws {
        let totalNanoseconds = timeInterval.totalNanoseconds
        guard totalNanoseconds > 0 else { return }
        try await sleep(nanoseconds: UInt64(totalNanoseconds))
    }
}
