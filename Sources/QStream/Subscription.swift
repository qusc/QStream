//
//  Subscription.swift
//  Subscription
//
//  Created by Quirin Schweigert on 15.09.21.
//

import Foundation

public protocol AnySubscription: Sendable {
    func store(in subscriptions: inout [AnySubscription])
//    func cancel() async
}

public extension AnySubscription {
    func store(in subscriptions: inout [AnySubscription]) {
        subscriptions.append(self)
    }
}

public final class Subscription<V: Sendable>: AnySubscription {
    let onAction: @Sendable (V) async -> Void
    let streamReference: any Stream
    
//    let onRemove: (@Sendable () -> Void)?
//    let onCancel: (@Sendable () async -> Void)?

    init(
        onAction: @Sendable @escaping (V) async -> Void,
        streamReference: any Stream
//        onRemove: (@Sendable () -> Void)? = nil,
//        onCancel: (@Sendable () -> Void)? = nil
    ) {
        self.onAction = onAction
        self.streamReference = streamReference
//        self.onRemove = onRemove
//        self.onCancel = onCancel
    }
    
//    public func cancel() async {
//        await onCancel?()
//    }
//    
//    deinit {
//        onRemove?()
//    }
}
