//
//  Stream+asyncPipe.swift
//  QStream
//

public extension Stream {
    /// Returns an `AsyncPipe` that receives values from this stream with
    /// backpressure: the stream's `send()` will block until the consumer has
    /// processed each value. The subscription is retained by the pipe.
    func asyncPipe() async -> AsyncPipe<V> {
        let pipe = AsyncPipe<V>()
        let subscription = subscribe { value in await pipe.push(value: value) }
        await pipe.setUpstreamSubscription(subscription)
        return pipe
    }
}
