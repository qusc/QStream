//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 10.01.22.
//

import Foundation

public extension Stream {
    func tap<A: Sendable, B: Sendable>(
        _ receiveValue: @escaping @Sendable (A, B) async -> Void
    ) async -> Subscription<V> where V == Streams.SendableTuple<A, B> {
        await tap { await receiveValue($0.a, $0.b) }
    }
}

public extension Stream {
    func tap<A: Sendable, B: Sendable, C: Sendable>(
        _ receiveValue: @escaping @Sendable (A, B, C) async -> Void
    ) async -> Subscription<V> where V == Streams.SendableTuple3<A, B, C> {
        await tap { await receiveValue($0.a, $0.b, $0.c) }
    }
}

public extension Stream {
    func tap<A: Sendable, B: Sendable, C: Sendable, D: Sendable>(
        _ receiveValue: @escaping @Sendable (A, B, C, D) async -> Void
    ) async -> Subscription<V> where V == Streams.SendableTuple4<A, B, C, D> {
        await tap { await receiveValue($0.a, $0.b, $0.c, $0.d) }
    }
}

public extension Stream {
    func map<A: Sendable, B: Sendable, T: Sendable>(transform: @escaping @Sendable (A, B) async -> T) async
    -> Streams.Map<Self, T> where V == Streams.SendableTuple<A, B> {
        await map { await transform($0.a, $0.b) }
    }
}

public extension Stream {
    func map<A: Sendable, B: Sendable, T: Sendable>(transform: @escaping @Sendable (A, B) async -> T) async
    -> Streams.Map<Self, T> where V == (A, B) {
        await map { await transform($0.0, $0.1) }
    }
}

public extension Stream {
    func compactMap<A: Sendable, B: Sendable, T: Sendable>(transform: @escaping @Sendable (A, B) async -> T?) async
    -> Streams.CompactMap<Self, T> where V == Streams.SendableTuple<A, B> {
        await compactMap { await transform($0.a, $0.b) }
    }
}

public extension Stream {
    func map<A: Sendable, B: Sendable, C: Sendable, T: Sendable>(transform: @escaping @Sendable (A, B, C) async -> T)
    async -> Streams.Map<Self, T> where V == Streams.SendableTuple3<A, B, C> {
        await map { await transform($0.a, $0.b, $0.c) }
    }
}

public extension Stream {
    func map<A: Sendable, B: Sendable, C: Sendable, D: Sendable, T: Sendable>(
        transform: @escaping @Sendable (A, B, C, D) async -> T
    ) async -> Streams.Map<Self, T> where V == Streams.SendableTuple4<A, B, C, D> {
        await map { await transform($0.a, $0.b, $0.c, $0.d) }
    }
}

public extension Stream {
    func map<A: Sendable, B: Sendable, C: Sendable, D: Sendable, E: Sendable, T: Sendable>(
        transform: @escaping @Sendable (A, B, C, D, E) async -> T
    ) async -> Streams.Map<Self, T> where V == Streams.SendableTuple5<A, B, C, D, E> {
        await map { await transform($0.a, $0.b, $0.c, $0.d, $0.e) }
    }
}

public extension Stream {
    func filter<A: Sendable, B: Sendable>(_ isIncluded: @escaping @Sendable (A, B) async -> Bool) async
    -> Streams.Filter<Self> where V == Streams.SendableTuple<A, B> {
        await filter { await isIncluded($0.a, $0.b) }
    }
}

public extension Stream {
    func filter<A: Sendable, B: Sendable>(_ isIncluded: @escaping @Sendable (A, B) async -> Bool) async
    -> Streams.Filter<Self> where V == (A, B) {
        await filter { await isIncluded($0.0, $0.1) }
    }
}

public extension Stream {
    func filter<A: Sendable, B: Sendable, C: Sendable>(_ isIncluded: @escaping @Sendable (A, B, C) async -> Bool) async
    -> Streams.Filter<Self> where V == Streams.SendableTuple3<A, B, C> {
        await filter { await isIncluded($0.a, $0.b, $0.c) }
    }
}

public extension Stream {
    func filter<A: Sendable, B: Sendable, C: Sendable, D: Sendable>(
        _ isIncluded: @escaping @Sendable (A, B, C, D) async -> Bool
    ) async -> Streams.Filter<Self> where V == Streams.SendableTuple4<A, B, C, D> {
        await filter { await isIncluded($0.a, $0.b, $0.c, $0.d) }
    }
}

public extension Sequence {
    func compactMap<A: Sendable, B: Sendable, T: Sendable>(_ transform: (A, B) throws -> T?) rethrows -> [T]
    where Element == Streams.SendableTuple<A, B> {
        try compactMap { try transform($0.a, $0.b) }
    }
}

//func subscribe(_ receiveValue: @escaping @Sendable (V) async -> Void) async -> Subscription<V>
//func tap(_ receiveValue: @escaping @Sendable (V) async -> Void) async -> Subscription<V>
