//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 27.06.24.
//

import Foundation

public extension Stream {
    func tapAsyncStream(
        bufferingPolicy: AsyncThrowingStream<V, any Error>.Continuation.BufferingPolicy = .unbounded
    ) async -> AsyncThrowingStream<V, Error> {
        let callbackInstalledSignal: AsyncBinarySemaphore = .init(value: false)
        
        let asyncStream = AsyncThrowingStream<V, Error>(bufferingPolicy: bufferingPolicy) {
            (continuation: AsyncThrowingStream<V, Error>.Continuation) -> Void in
            Task {
                let subscription: ValueActor<AnySubscription?> = .init()
                await subscription.set(value: self.tap { value in
                    continuation.yield(value)
                })
                
                continuation.onTermination = { _ in
                    Task {
                        await subscription.set(value: nil)
                        continuation.finish(throwing: CancellationError())
                    }
                }
                
                await callbackInstalledSignal.signal()
            }
        }
        
        await callbackInstalledSignal.wait()
        return asyncStream
    }
    
    func asyncStream(debugLabel: String? = .none) async -> AsyncThrowingStream<V, Error> {
        let callbackInstalledSignal: AsyncBinarySemaphore = .init(value: false)
        
        let asyncStream = AsyncThrowingStream<V, Error> {
            (continuation: AsyncThrowingStream<V, Error>.Continuation) -> Void in
            Task {
                let subscription: ValueActor<AnySubscription?> = .init()
                await subscription.set(value: self.subscribe { value in
                    continuation.yield(value)
                })
                
                continuation.onTermination = { _ in
                    if let debugLabel {
                        Swift.print(debugLabel)
                    }
                    
                    Task {
                        await subscription.set(value: nil)
                        continuation.finish(throwing: CancellationError())
                    }
                }
                
                await callbackInstalledSignal.signal()
            }
        }
        
        await callbackInstalledSignal.wait()
        return asyncStream
    }
}
