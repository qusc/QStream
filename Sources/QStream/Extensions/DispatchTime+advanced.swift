//
//  File.swift
//  File
//
//  Created by Quirin Schweigert on 14.10.21.
//

import Foundation

#if !(os(macOS) || os(iOS) || os(watchOS))
public extension DispatchTime {
    func advanced(by interval: DispatchTimeInterval) -> DispatchTime {
        let signedUptimeNanoseconds = Int64(uptimeNanoseconds) + interval.totalNanoseconds
        guard signedUptimeNanoseconds >= 0 else { return DispatchTime(uptimeNanoseconds: 0) }
        return DispatchTime(uptimeNanoseconds: UInt64(signedUptimeNanoseconds))
    }
    
    func distance(to other: DispatchTime) -> DispatchTimeInterval {
        guard other.uptimeNanoseconds <= UInt64(Int.max / 2), self.uptimeNanoseconds <= UInt64(Int.max / 2) else {
            return .never
        }
        
        return .nanoseconds(Int(other.uptimeNanoseconds) - Int(self.uptimeNanoseconds))
    }
}
#endif
