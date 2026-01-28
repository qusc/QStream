//
//  Stream.swift
//  
//
//  Created by Quirin Schweigert on 16.12.21.
//

import Foundation

public enum Streams { }

/// QStream: Reactive programming framework
/// 
/// Note: Designed for observing current value of a unit of observable state (`Stream`). If used to process sequence of values, need to ensure subscription is in
/// place before values are sent upstream.
/// Motivation: Combine & RxSwift: can't deal with async closures for receiving and transforming values. Also various other unfortunate quirks like Combine sending
/// values in a random order, making debbugging unnecessarily hard.
/// Other notable differences to these frameworks: values can be buffered ("multicast") at every point in the stream chain. Also: function to query `currentValue`
/// of a Stream.
public protocol Stream<V>: Actor {
    associatedtype V: Sendable
    
    var subscriptions: [Weak<Subscription<V>>] { get set }
    
    /// Required to ensure that values are processed by sybscribers in the same order they are sent
    var sendValuesSemaphore: AsyncBinarySemaphore { get }
    
    /// If this returns a value it means that this Stream is supposed to have a current value at all times and downstream Streams should buffer and supply their
    /// own current value
    func currentValue() async -> V?
    
    /// Send values to all subscribers.
    func send(_ value: V) async
    
    /// Receive all futures values on this stream.
    func subscribe(_ receiveValue: @escaping @Sendable (V) async -> Void) -> Subscription<V>
    
    /// Receive the current value as well as future values on this stream.
    func tap(_ receiveValue: @escaping @Sendable (V) async -> Void) async -> Subscription<V>
    
}

public extension Stream {
    /// `send(_:)` prevents sending any new values before all previous values have been processed in order to preserve the processing order of sent values.
    func send(_ value: V) async {
        await sendValuesSemaphore.wait()

        var index = 0
        /// Combining sending value and cleaning up subscriptions that were deallocated in one iteration pass over `subscriptions`
        while index < subscriptions.count {
            if let subscription = subscriptions[index].value {
                await subscription.onAction(value)
                index += 1
            } else {
                subscriptions.remove(at: index)
            }
        }
        
        await sendValuesSemaphore.signal()
    }
    
    func subscribe(_ receiveValue: @escaping @Sendable (V) async -> Void) -> Subscription<V> {
        let subscription = Subscription(
            onAction: receiveValue,

            /// Hold a reference to keep this `Stream` from being deallocated as long as the subscription is in memory
            streamReference: self
        )
        
        subscriptions.append(Weak(value: subscription))
        return subscription
    }
    
    func tap(_ receiveValue: @escaping @Sendable (V) async -> Void) async -> Subscription<V> {
        await sendValuesSemaphore.wait()
        
        let subscription = subscribe(receiveValue)

        if let currentValue = await currentValue() {
            await receiveValue(currentValue)
        }
        
        await sendValuesSemaphore.signal()
        
        return subscription
    }
    
    func subscribe(
        _ receiveValue: @escaping @Sendable (V) async -> Void,
        receiveCurrentValue: @escaping @Sendable (V) async -> Void
    ) async -> Subscription<V> {
        await sendValuesSemaphore.wait()
        
        let subscription = subscribe(receiveValue)

        if let currentValue = await currentValue() {
            await receiveCurrentValue(currentValue)
        }
        
        await sendValuesSemaphore.signal()
        
        return subscription
    }
}

public extension Streams {
    static func createSemaphore() -> AsyncBinarySemaphore {
        .init(debugDeadlockDetection: true)
    }
}
