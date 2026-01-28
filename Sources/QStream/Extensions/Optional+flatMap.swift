//
//  Optional+flatMap.swift
//  VoiceBeam
//
//  Created by Quirin Schweigert on 14.12.21.
//

import Foundation

public extension Optional {
    func flatMapAsync<U>(_ transform: (Wrapped) async throws -> U?) async rethrows -> U? {
        if let self { return try await transform(self) }
        else { return nil }
    }
}
