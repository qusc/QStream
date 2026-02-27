//
//  Stream+getFuture.swift
//  QStream
//

public extension Stream {
    func getFuture() async -> Task<V, Error> {
        let stream = await asyncStream()

        return Task {
            for try await value in stream {
                return value
            }

            throw CancellationError()
        }
    }

    func getFuture<T: Sendable>(
        compactMap transform: @escaping @Sendable (V) async -> T?
    ) async -> Task<T, Error> {
        let stream = await asyncStream()

        return Task {
            for try await value in stream {
                if let transformed = await transform(value) {
                    return transformed
                }
            }

            throw CancellationError()
        }
    }
}
