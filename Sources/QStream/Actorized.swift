//
//  Actorized.swift
//  VoiceBeam
//
//  Created by Quirin Schweigert on 28.03.22.
//

import Foundation

public actor Synced<T> {
    public var value: T

    public init(_ value: T) {
        self.value = value
    }

    public func set(_ value: T) {
        self.value = value
    }
}
