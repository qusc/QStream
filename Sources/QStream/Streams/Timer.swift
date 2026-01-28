//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 19.01.22.
//

import Foundation

public extension Streams {
    actor Timer: Stream {
        public typealias V = Void
        
        let interval: DispatchTimeInterval
        let preventDrift: Bool
        var nextEmitTime: DispatchTime
        
        public var subscriptions: [Weak<Subscription<Void>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        var emitTask: Task<Void, Error>?
        
        public func currentValue() async -> Void? {
            nil
        }
        
        public init(interval: DispatchTimeInterval, preventDrift: Bool = true, repeat: Bool = true) async {
            self.interval = interval
            self.preventDrift = preventDrift
            nextEmitTime = .now().advanced(by: interval)
            
            emitTask = Task { [weak self] in
                guard let preventDrift = self?.preventDrift, let interval = self?.interval else { return }
                
                while !Task.isCancelled {
                    guard let nextEmitTime = await self?.nextEmitTime else { return }
                    let sleepTime = DispatchTime.now().distance(to: nextEmitTime)
                    
                    if sleepTime.totalNanoseconds >= 0 {
                        try await Task.sleep(nanoseconds: UInt64(sleepTime.totalNanoseconds))
                    }
                    
                    await self?.send(())
                    
                    guard `repeat` else { return }
                    
                    await self?.set(
                        nextEmitTime: preventDrift ? nextEmitTime.advanced(by: interval) : .now().advanced(by: interval)
                    )
                }
            }
        }
        
        deinit {
            self.emitTask?.cancel()
        }
        
        func set(nextEmitTime: DispatchTime) {
            self.nextEmitTime = nextEmitTime
        }
    }
}
