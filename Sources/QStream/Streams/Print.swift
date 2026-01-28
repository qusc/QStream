//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 13.01.22.
//

import Foundation
import Logging

public extension Streams {
    actor Print<Upstream: Stream>: Stream {
        let label: String
        let printDate: Bool
        let logger: Logger?
        let level: Logger.Level
        
        public var subscriptions: [Weak<Subscription<Upstream.V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstream: Upstream
        var upstreamSubscription: AnySubscription?

        public func currentValue() async -> Upstream.V? {
            await upstream.currentValue()
        }
        
        public init(
            upstream: Upstream,
            label: String,
            printDate: Bool = false,
            logger: Logger?,
            level: Logger.Level = .debug
        ) async {
            self.upstream = upstream
            self.label = label
            self.printDate = printDate
            self.logger = logger
            self.level = level
            
            let currentValue = await currentValue()
            let message = { "\(label): (initial value) \(String(describing: currentValue))" }
            if let logger { logger.debug("\(message())") } else { Swift.print(message()) }
            
            upstreamSubscription = await upstream
                .subscribe { [weak self] value in
                    guard let self else { return }
                    let message = { "\(printDate ? "\(Date()) " : "")\(label): \(value)" }
                    //                    let message = { "\(printDate ? "\(Date()) " : "")\(label): \("\(value)".filter { !$0.isNewline })" }
                    if let logger { logger.debug("\(message())") } else { Swift.print(message()) }
                    await self.send(value)
//                    let endMessage = { "\(printDate ? "\(Date()) " : "")\(label) (done processing): \("\(value)".filter { !$0.isNewline })" }
//                    if let logger { logger.debug("\(endMessage())") } else { Swift.print(endMessage()) }
                }
        }
    }
}

public extension Stream {
    func print(
        _ label: String,
        printDate: Bool = false,
        logger: Logger? = .none,
        level: Logger.Level = .debug
    ) async -> Streams.Print<Self> {
        return await Streams.Print(upstream: self, label: label, printDate: printDate, logger: logger, level: level)
    }
}

