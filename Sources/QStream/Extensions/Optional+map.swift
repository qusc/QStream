//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 04.01.22.
//

import Foundation

public extension Optional {
    func mapAsync<U>(_ transform: (Wrapped) async throws -> U) async rethrows -> U? {
        if let self { return try await transform(self) }
        else { return nil }
    }
    
    /// Helper created because nil-coalescing operator doesn't support `async` call (in auto-closure)
    func map<U>(_ transform: (Wrapped) async throws -> U, `default`: () async throws -> U) async rethrows -> U {
        if let self { return try await transform(self) }
        else { return try await `default`() }
    }
}
