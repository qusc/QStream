//
//  File.swift
//
//
//  Created by Quirin Schweigert on 27.06.24.
//

import Foundation

public extension Stream {
    func pulse(ofLength pulseLength: DispatchTimeInterval) async -> AnyStream<V?> {
        await self
            .map {
                let pulseSource = Subject<V?>(value: $0)
                let pulseEmitter = await pulseSource.throttle(for: pulseLength)
                await pulseSource.set(nil)
                return pulseEmitter
            }
            .switchToLatest()
            .any()
    }
    
    func pulseOptional<Wrapped>(ofLength pulseLength: DispatchTimeInterval) async
    -> AnyStream<V> where V == Wrapped? {
        await self
            .map {
                let pulseSource = Subject<V>(value: $0)
                let pulseEmitter = await pulseSource.throttle(for: pulseLength)
                await pulseSource.set(nil)
                return pulseEmitter
            }
            .switchToLatest()
            .any()
    }
}
