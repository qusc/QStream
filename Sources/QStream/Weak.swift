//
//  Weak.swift
//  Weak
//
//  Created by Quirin Schweigert on 15.09.21.
//

import Foundation

public final class Weak<T: AnyObject> {
    public weak var value : T?
    
    public init (value: T) {
        self.value = value
    }
}
