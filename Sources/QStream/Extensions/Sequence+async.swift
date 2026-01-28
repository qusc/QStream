//
//  Sequence+async.swift
//  Async Array Extensions
//
//  Created by Quirin Schweigert on 28.09.21.
//

import Foundation

public extension Sequence {
    func mapAsync<T>(_ transform: @Sendable (Element) async throws -> T) async rethrows -> [T] {
        var mapped: [T] = []
        
        for element in self {
            mapped.append(try await transform(element))
        }
        
        return mapped
    }

    func filterAsync(_ isIncluded: @Sendable (Element) async throws -> Bool) async rethrows -> [Element] {
        var filtered: [Element] = []
        
        for element in self {
            if try await isIncluded(element) {
                filtered.append(element)
            }
        }
        
        return filtered
    }
    
    func compactMapAsync<T>(_ transform: @Sendable (Element) async throws -> T?) async rethrows -> [T] {
        var mapped: [T] = []
        
        for element in self {
            if let transformed = try await transform(element) {
                mapped.append(transformed)
            }
        }
        
        return mapped
    }
    
    func forEachAsync(_ body: @Sendable (Element) async throws -> Void) async rethrows {
        for element in self {
            try await body(element)
        }
    }
    
    func filter(_ isIncluded: @Sendable (Self.Element) async throws -> Bool) async rethrows -> [Self.Element] {
        var filtered: [Element] = []
        
        for element in self {
            if try await isIncluded(element) {
                filtered.append(element)
            }
        }
        
        return filtered
    }
    
    func flatMapAsync<SegmentOfResult>(_ transform: @Sendable (Self.Element) async throws -> SegmentOfResult)
    async rethrows -> [SegmentOfResult.Element] where SegmentOfResult : Sequence {
        try await mapAsync(transform).flatMap { $0 }
    }

    /// https://chatgpt.com/share/68765be5-2f04-8008-bec1-fb53dafd2bfe
    ///
    /// Returns `true` if any element of the sequence satisfies the given asynchronous predicate.
    ///
    /// - Parameter predicate: An asynchronous closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element should be included.
    /// - Returns: `true` if the sequence contains an element that satisfies `predicate`; otherwise, `false`.
    func containsAsync(where predicate: @Sendable (Element) async throws -> Bool) async rethrows -> Bool {
        for element in self {
            if try await predicate(element) {
                return true
            }
        }
        
        return false
    }
}

public extension Sequence where Element: Sendable {
    func forEachConcurrent(_ body: @escaping @Sendable (Element) async -> Void) async {
        await withTaskGroup(of: Void.self) { taskGroup in
            forEach { element in
                taskGroup.addTask { await body(element) }
            }
            
            await taskGroup.waitForAll()
        }
    }
    
    func forEachConcurrent(_ body: @escaping @Sendable (Element) async throws -> Void) async throws {
        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            forEach { element in
                taskGroup.addTask { try await body(element) }
            }
            
            try await taskGroup.waitForAll()
        }
    }
    
    func mapConcurrent<V: Sendable>(
        orderBy orderingStrategy: MapConcurrentOrderingStrategy = .preserving,
        _ body: @escaping @Sendable (Element) async -> V
    ) async -> [V] {
        await withTaskGroup(of: (Int, V).self) { taskGroup in
            var results: [(offset: Int, value: V)] = []
            enumerated().forEach { offset, element in taskGroup.addTask { await (offset, body(element)) } }
            for await result in taskGroup { results.append(result) }

            switch orderingStrategy {
            case .completion:
                return results.map { $0.value }
            case .preserving:
                var resultsWithPreservedOrder: [V?] = .init(repeating: .none, count: results.count)
                for (offset, value) in results { resultsWithPreservedOrder[offset] = value }
                return resultsWithPreservedOrder.compactMap { $0 }
            }
        }
    }
    
    func mapConcurrent<V: Sendable>(
        orderBy orderingStrategy: MapConcurrentOrderingStrategy = .preserving,
        _ body: @escaping @Sendable (Element) async throws -> V
    ) async throws -> [V] {
        try await withThrowingTaskGroup(of: (Int, V).self) { taskGroup in
            var results: [(offset: Int, value: V)] = []
            enumerated().forEach { offset, element in taskGroup.addTask { try await (offset, body(element)) } }
            for try await result in taskGroup { results.append(result) }
            
            switch orderingStrategy {
            case .completion:
                return results.map { $0.value }
            case .preserving:
                var resultsWithPreservedOrder: [V?] = .init(repeating: .none, count: results.count)
                for (offset, value) in results { resultsWithPreservedOrder[offset] = value }
                return resultsWithPreservedOrder.compactMap { $0 }
            }
        }
    }
}

public enum MapConcurrentOrderingStrategy {
    case preserving
    case completion
}

public extension Dictionary {
    func mapValuesConcurrent<T: Sendable>(_ transform: @escaping @Sendable (Value) async -> T) async
    -> Dictionary<Key, T> where Self: Sendable {
        .init(uniqueKeysWithValues: await withTaskGroup(of: (Key, T).self) { taskGroup in
            var results: [(Key, T)] = []
            forEach { key, value in taskGroup.addTask { (key, await transform(value)) } }
            for await result in taskGroup { results.append(result) }
            return results
        })
    }
}

//public extension Set {
//    func compactMapAsync<T>(_ transform: (Element) async -> T?) async -> [T] {
//        var mapped: [T] = []
//
//        for element in self {
//            if let transformed = await transform(element) {
//                mapped.append(transformed)
//            }
//        }
//
//        return mapped
//    }
//}
