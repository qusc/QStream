//
//  UncheckedSendable.swift
//
//  Created by Quirin Schweigert on 15.09.21.
//

import Foundation

extension DispatchTimeInterval: @unchecked Sendable { }
extension DispatchTime: @unchecked Sendable { }
