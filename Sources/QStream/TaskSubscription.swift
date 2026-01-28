//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 04.07.24.
//

import Foundation

public actor TaskSubscription<Upstream: Stream>: AnySubscription {
    let execute: @Sendable (Upstream.V) async throws -> Void
    var upstreamSubscription: Subscription<Upstream.V>?
    var currentTask: Task<Void, Error>?
    
    init(upstream: Upstream, execute: @Sendable @escaping (Upstream.V) async throws -> Void) async {
        self.execute = execute
        
        upstreamSubscription = await upstream.tap { [weak self] upstreamValue in
            await self?.handleUpstreamValue(upstreamValue)
        }
    }
    
    private func handleUpstreamValue(_ value: Upstream.V) {
        currentTask?.cancel()
        
        /// Note: super important to not implicitly capture `self` here but only `execute` to avoid memory leak
        currentTask = Task { [execute] in try await execute(value) }
    }
    
    deinit {
        print("sr \(Self.self) deinit")
        currentTask?.cancel()
    }
}

public extension Stream {
    func task(execute: @Sendable @escaping (V) async throws -> Void) async -> TaskSubscription<Self> {
        await .init(upstream: self, execute: execute)
    }
}
