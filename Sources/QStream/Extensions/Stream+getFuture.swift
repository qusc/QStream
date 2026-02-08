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
}
