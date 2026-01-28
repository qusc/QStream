//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 26.03.24.
//

import Foundation

public extension Result where Failure == any Error {
    init(catching body: @Sendable () async throws -> Success) async {
        do {
            self = .success(try await body())
        } catch {
            self = .failure(error)
        }
    }
}
