//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 08.02.22.
//

import Foundation

public extension Task where Success == Never, Failure == Never {
    static func sleep(until dispatchTime: DispatchTime) async throws {
        let sleepTime = DispatchTime.now().distance(to: dispatchTime).totalNanoseconds
        guard sleepTime >= 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(sleepTime))
    }
}
