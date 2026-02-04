//
//  Logger+sub.swift
//  QStream
//
//  Created by Quirin Schweigert on 09.12.24.
//

import Logging

public extension Logger {
    func sub(
        label: @autoclosure () -> String = #file,
        metadata: Logger.Metadata = [:],
        level: Level? = .none
    ) -> Logger {
        var logger = self

        let label = label()
        logger[metadataKey: "source"] = "\(label.split(separator: "/").last?.removingSuffix(".swift") ?? "none")"

        for (key, value) in metadata {
            logger[metadataKey: key] = "\(value)"
        }

        if let level {
            logger.logLevel = level
        }

        return logger
    }
}

extension StringProtocol {
    func removingSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else { return .init(self) }
        return String(dropLast(suffix.count))
    }
}
