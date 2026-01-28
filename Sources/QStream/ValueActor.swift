//
//  ValueActor.swift
//  ValueActor
//
//  Created by Quirin Schweigert on 28.09.21.
//

public actor ValueActor<V: Sendable> {
    public var value: V
    public init(value: V) { self.value = value }
    public func set(value: V) { self.value = value }
    public func execute(_ body: @Sendable (inout V) -> Void) { body(&value) }
    public func execute<R: Sendable>(_ body: @Sendable (inout V) -> R) -> R { body(&value) }
}

public extension ValueActor {
    init<Wrapped>() where V == Wrapped? {
        self.init(value: nil)
    }
}
