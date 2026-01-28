//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 13.03.23.
//

import Foundation

public extension Stream {
    func scan<A: Sendable, B: Sendable, T: Sendable>(
        initialResult: T,
        _ nextPartialResult: @escaping @Sendable (T, A, B) async -> T
    ) async -> Streams.Scan<Self, T> where V == (A, B) {
        await Streams.Scan(upstream: self, initialResult: initialResult) { accumulator, tuple in
            await nextPartialResult(accumulator, tuple.0, tuple.1)
        }
    }
}
