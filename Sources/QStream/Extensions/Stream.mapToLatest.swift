//
//  Stream.mapToLatest.swift
//  QStream
//
//  Created by Quirin Schweigert on 08.03.25.
//

public extension Stream {
    func mapOptionalToLatest<O, S: Stream>(`default`: S.V, transform: @escaping @Sendable (O) async -> S)
    async -> Streams.SwitchToLatest<Streams.Map<Self, AnyStream<S.V>>, AnyStream<S.V>> where V == (Optional<O>) {
        await self
            .map { @Sendable (value: Optional<O>) -> AnyStream<S.V> in
                if let value { await transform(value).any() }
                else { await Subject(value: `default`).any() }
            }
            .switchToLatest()
    }
}
