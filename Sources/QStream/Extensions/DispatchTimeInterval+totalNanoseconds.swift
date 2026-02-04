//
//  File.swift
//  File
//
//  Created by Quirin Schweigert on 14.10.21.
//

import Foundation

// https://forums.swift.org/t/why-is-dispatchtimeinterval-not-comparable/15484
extension DispatchTimeInterval: Comparable {
    var totalNanoseconds: Int64 {
        switch self {
        case .nanoseconds(let ns): return Int64(ns)
        case .microseconds(let us): return Int64(us) * 1_000
        case .milliseconds(let ms): return Int64(ms) * 1_000_000
        case .seconds(let s): return Int64(s) * 1_000_000_000
        case .never: fatalError("infinite nanoseconds")
        @unknown default:
            fatalError("unknown default")
        }
    }
    
    public static func <(lhs: DispatchTimeInterval, rhs: DispatchTimeInterval) -> Bool {
        if lhs == .never { return false }
        if rhs == .never { return true }
        return lhs.totalNanoseconds < rhs.totalNanoseconds
    }
}
