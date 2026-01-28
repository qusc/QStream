//
//  File.swift
//
//
//  Created by Quirin Schweigert on 05.01.22.
//

import Foundation

public extension Streams {
    struct SendableTuple<A: Sendable, B: Sendable>: Sendable, CustomStringConvertible {
        public var a: A
        public var b: B
        
        public init(_ a: A, _ b: B) {
            self.a = a
            self.b = b
        }
        
        public var description: String {
            "(a: \(a), b: \(b))"
        }
    }
    
    actor CombineLatest<A: Stream, B: Stream>: Stream {
        public typealias V = (A.V, B.V)
        
        public var subscriptions: [Weak<Subscription<V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstreamA: A
        let upstreamB: B
        
        var upstreamSubscriptions: [AnySubscription] = []
        
        var valueA: A.V?
        var valueB: B.V?
        
        public init(_ StreamA: A, _ StreamB: B) async {
            upstreamA = StreamA
            upstreamB = StreamB
            await subscribeUpstreams()
        }
        
        /// Semantics of `CombineLatest`: Stream will have a current value as soon as any value could be obtained by all upstream Streams.
        public func currentValue() async -> (A.V, B.V)? {
            guard let a = valueA, let b = valueB else { return nil }
            return (a, b)
        }
        
        private func subscribeUpstreams() async {
            guard upstreamSubscriptions.isEmpty else { return }
            
            await upstreamA
                .tap { [weak self] value in
                    await self?.setValueA(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamB
                .tap { [weak self] value in
                    await self?.setValueB(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
        }
        
        private func setValueA(_ valueA: A.V) {
            self.valueA = valueA
        }
        
        private func setValueB(_ valueB: B.V) {
            self.valueB = valueB
        }
        
        private func sendValues() async {
            if let currentValue = await currentValue() {
                await send(currentValue)
            }
        }
    }
    
    struct SendableTuple3<A: Sendable, B: Sendable, C: Sendable>: Sendable, CustomStringConvertible {
        public var a: A
        public var b: B
        public var c: C

        public init(_ a: A, _ b: B, _ c: C) {
            self.a = a
            self.b = b
            self.c = c
        }

        public var description: String {
            "(a: \(a), b: \(b), c: \(c))"
        }
    }

    actor CombineLatest3<A: Stream, B: Stream, C: Stream>: Stream {
        public typealias V = (A.V, B.V, C.V)
        
        public var subscriptions: [Weak<Subscription<V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstreamA: A
        let upstreamB: B
        let upstreamC: C
        
        var upstreamSubscriptions: [AnySubscription] = []
        
        var valueA: A.V?
        var valueB: B.V?
        var valueC: C.V?
        
        public init(_ StreamA: A, _ StreamB: B, _ StreamC: C) async {
            upstreamA = StreamA
            upstreamB = StreamB
            upstreamC = StreamC
            await subscribeUpstreams()
        }

        public func currentValue() async -> (A.V, B.V, C.V)? {
            guard let a = valueA, let b = valueB, let c = valueC else { return nil }
            return (a, b, c)
        }

        private func subscribeUpstreams() async {
            guard upstreamSubscriptions.isEmpty else { return }
            
            await upstreamA
                .tap { [weak self] value in
                    await self?.setValueA(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamB
                .tap { [weak self] value in
                    await self?.setValueB(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamC
                .tap { [weak self] value in
                    await self?.setValueC(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
        }
        
        private func setValueA(_ valueA: A.V) {
            self.valueA = valueA
        }
        
        private func setValueB(_ valueB: B.V) {
            self.valueB = valueB
        }
        
        private func setValueC(_ valueC: C.V) {
            self.valueC = valueC
        }
        
        private func sendValues() async {
            if let currentValue = await currentValue() {
                await send(currentValue)
            }
        }
    }
    
    struct SendableTuple4<A: Sendable, B: Sendable, C: Sendable, D: Sendable>: Sendable, CustomStringConvertible {
        public var a: A
        public var b: B
        public var c: C
        public var d: D
        
        public init(_ a: A, _ b: B, _ c: C, _ d: D) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
        }
        
        public var description: String {
            "(a: \(a), b: \(b), c: \(c), d: \(d))"
        }
    }
    
    actor CombineLatest4<A: Stream, B: Stream, C: Stream, D: Stream>: Stream {
        public typealias V = (A.V, B.V, C.V, D.V)
        
        public var subscriptions: [Weak<Subscription<V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstreamA: A
        let upstreamB: B
        let upstreamC: C
        let upstreamD: D
        
        var upstreamSubscriptions: [AnySubscription] = []
        
        var valueA: A.V?
        var valueB: B.V?
        var valueC: C.V?
        var valueD: D.V?
        
        public init(_ StreamA: A, _ StreamB: B, _ StreamC: C, _ StreamD: D) async {
            upstreamA = StreamA
            upstreamB = StreamB
            upstreamC = StreamC
            upstreamD = StreamD
            await subscribeUpstreams()
        }
        
        public func currentValue() async -> (A.V, B.V, C.V, D.V)? {
            guard let a = valueA, let b = valueB, let c = valueC, let d = valueD else { return nil }
            return (a, b, c, d)
        }
        
        private func subscribeUpstreams() async {
            guard upstreamSubscriptions.isEmpty else { return }
            
            await upstreamA
                .tap { [weak self] value in
                    await self?.setValueA(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamB
                .tap { [weak self] value in
                    await self?.setValueB(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamC
                .tap { [weak self] value in
                    await self?.setValueC(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamD
                .tap { [weak self] value in
                    await self?.setValueD(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
        }
        
        private func setValueA(_ valueA: A.V) {
            self.valueA = valueA
        }
        
        private func setValueB(_ valueB: B.V) {
            self.valueB = valueB
        }
        
        private func setValueC(_ valueC: C.V) {
            self.valueC = valueC
        }
        
        private func setValueD(_ valueD: D.V) {
            self.valueD = valueD
        }
        
        private func sendValues() async {
            if let currentValue = await currentValue() {
                await send(currentValue)
            }
        }
    }
    
    struct SendableTuple5<
        A: Sendable, B: Sendable, C: Sendable, D: Sendable, E: Sendable
    >: Sendable, CustomStringConvertible {
        public var a: A
        public var b: B
        public var c: C
        public var d: D
        public var e: E
        
        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
        }
        
        public var description: String {
            "(a: \(a), b: \(b), c: \(c), d: \(d), e: \(e))"
        }
    }
    
    actor CombineLatest5<A: Stream, B: Stream, C: Stream, D: Stream, E: Stream>: Stream {
        public typealias V = (A.V, B.V, C.V, D.V, E.V)
        
        public var subscriptions: [Weak<Subscription<V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstreamA: A
        let upstreamB: B
        let upstreamC: C
        let upstreamD: D
        let upstreamE: E
        
        var upstreamSubscriptions: [AnySubscription] = []
        
        var valueA: A.V?
        var valueB: B.V?
        var valueC: C.V?
        var valueD: D.V?
        var valueE: E.V?
        
        public init(_ streamA: A, _ streamB: B, _ streamC: C, _ streamD: D, _ streamE: E) async {
            upstreamA = streamA
            upstreamB = streamB
            upstreamC = streamC
            upstreamD = streamD
            upstreamE = streamE
            await subscribeUpstreams()
        }
        
        public func currentValue() async -> (A.V, B.V, C.V, D.V, E.V)? {
            guard let a = valueA, let b = valueB, let c = valueC, let d = valueD, let e = valueE else { return nil }
            return (a, b, c, d, e)
        }
        
        private func subscribeUpstreams() async {
            guard upstreamSubscriptions.isEmpty else { return }
            
            await upstreamA
                .tap { [weak self] value in
                    await self?.setValueA(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamB
                .tap { [weak self] value in
                    await self?.setValueB(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamC
                .tap { [weak self] value in
                    await self?.setValueC(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamD
                .tap { [weak self] value in
                    await self?.setValueD(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamE
                .tap { [weak self] value in
                    await self?.setValueE(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
        }
        
        private func setValueA(_ valueA: A.V) {
            self.valueA = valueA
        }
        
        private func setValueB(_ valueB: B.V) {
            self.valueB = valueB
        }
        
        private func setValueC(_ valueC: C.V) {
            self.valueC = valueC
        }
        
        private func setValueD(_ valueD: D.V) {
            self.valueD = valueD
        }
        
        private func setValueE(_ valueE: E.V) {
            self.valueE = valueE
        }
        
        private func sendValues() async {
            if let currentValue = await currentValue() {
                await send(currentValue)
            }
        }
    }
    
    actor CombineLatest6<A: Stream, B: Stream, C: Stream, D: Stream, E: Stream, F: Stream>: Stream {
        public typealias V = (A.V, B.V, C.V, D.V, E.V, F.V)
        
        public var subscriptions: [Weak<Subscription<V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        let upstreamA: A
        let upstreamB: B
        let upstreamC: C
        let upstreamD: D
        let upstreamE: E
        let upstreamF: F
        
        var upstreamSubscriptions: [AnySubscription] = []
        
        var valueA: A.V?
        var valueB: B.V?
        var valueC: C.V?
        var valueD: D.V?
        var valueE: E.V?
        var valueF: F.V?
        
        public init(_ streamA: A, _ streamB: B, _ streamC: C, _ streamD: D, _ streamE: E, _ streamF: F) async {
            upstreamA = streamA
            upstreamB = streamB
            upstreamC = streamC
            upstreamD = streamD
            upstreamE = streamE
            upstreamF = streamF
            await subscribeUpstreams()
        }
        
        public func currentValue() async -> (A.V, B.V, C.V, D.V, E.V, F.V)? {
            guard let a = valueA, let b = valueB, let c = valueC, let d = valueD, let e = valueE,
                    let f = valueF else { return nil }
            return (a, b, c, d, e, f)
        }
        
        private func subscribeUpstreams() async {
            guard upstreamSubscriptions.isEmpty else { return }
            
            await upstreamA
                .tap { [weak self] value in
                    await self?.setValueA(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamB
                .tap { [weak self] value in
                    await self?.setValueB(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamC
                .tap { [weak self] value in
                    await self?.setValueC(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamD
                .tap { [weak self] value in
                    await self?.setValueD(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamE
                .tap { [weak self] value in
                    await self?.setValueE(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamF
                .tap { [weak self] value in
                    await self?.setValueF(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
        }
        
        private func setValueA(_ valueA: A.V) {
            self.valueA = valueA
        }
        
        private func setValueB(_ valueB: B.V) {
            self.valueB = valueB
        }
        
        private func setValueC(_ valueC: C.V) {
            self.valueC = valueC
        }
        
        private func setValueD(_ valueD: D.V) {
            self.valueD = valueD
        }
        
        private func setValueE(_ valueE: E.V) {
            self.valueE = valueE
        }
        
        private func setValueF(_ valueF: F.V) {
            self.valueF = valueF
        }
        
        private func sendValues() async {
            if let currentValue = await currentValue() {
                await send(currentValue)
            }
        }
    }

    actor CombineLatest7<A: Stream, B: Stream, C: Stream, D: Stream, E: Stream, F: Stream, G: Stream>: Stream {
        public typealias V = (A.V, B.V, C.V, D.V, E.V, F.V, G.V)

        public var subscriptions: [Weak<Subscription<V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()

        let upstreamA: A
        let upstreamB: B
        let upstreamC: C
        let upstreamD: D
        let upstreamE: E
        let upstreamF: F
        let upstreamG: G

        var upstreamSubscriptions: [AnySubscription] = []

        var valueA: A.V?
        var valueB: B.V?
        var valueC: C.V?
        var valueD: D.V?
        var valueE: E.V?
        var valueF: F.V?
        var valueG: G.V?

        public init(
            _ streamA: A,
            _ streamB: B,
            _ streamC: C,
            _ streamD: D,
            _ streamE: E,
            _ streamF: F,
            _ streamG: G
        ) async {
            upstreamA = streamA
            upstreamB = streamB
            upstreamC = streamC
            upstreamD = streamD
            upstreamE = streamE
            upstreamF = streamF
            upstreamG = streamG
            await subscribeUpstreams()
        }

        public func currentValue() async -> (A.V, B.V, C.V, D.V, E.V, F.V, G.V)? {
            guard let a = valueA, let b = valueB, let c = valueC, let d = valueD,
                  let e = valueE, let f = valueF, let g = valueG else { return nil }
            return (a, b, c, d, e, f, g)
        }
        
        private func subscribeUpstreams() async {
            guard upstreamSubscriptions.isEmpty else { return }
            
            await upstreamA
                .tap { [weak self] value in
                    await self?.setValueA(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamB
                .tap { [weak self] value in
                    await self?.setValueB(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamC
                .tap { [weak self] value in
                    await self?.setValueC(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamD
                .tap { [weak self] value in
                    await self?.setValueD(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamE
                .tap { [weak self] value in
                    await self?.setValueE(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamF
                .tap { [weak self] value in
                    await self?.setValueF(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
            
            await upstreamG
                .tap { [weak self] value in
                    await self?.setValueG(value)
                    await self?.sendValues()
                }
                .store(in: &upstreamSubscriptions)
        }

        private func setValueA(_ valueA: A.V) { self.valueA = valueA }
        private func setValueB(_ valueB: B.V) { self.valueB = valueB }
        private func setValueC(_ valueC: C.V) { self.valueC = valueC }
        private func setValueD(_ valueD: D.V) { self.valueD = valueD }
        private func setValueE(_ valueE: E.V) { self.valueE = valueE }
        private func setValueF(_ valueF: F.V) { self.valueF = valueF }
        private func setValueG(_ valueG: G.V) { self.valueG = valueG }

        private func sendValues() async {
            if let currentValue = await currentValue() {
                await send(currentValue)
            }
        }
    }
    
    actor CombineLatestCollection<C: Collection & Sendable>: Stream where C.Element: Stream {
        public typealias V = [C.Element.V]
        
        public var subscriptions: [Weak<Subscription<V>>] = []
        public var sendValuesSemaphore: AsyncBinarySemaphore = Streams.createSemaphore()
        
        var upstreamSubscriptions: [AnySubscription] = []
        
        var latestValues: [C.Element.V?]
        
        public init(upstreams: C) async {
            latestValues = .init(repeating: nil, count: upstreams.count)
            
            upstreamSubscriptions = await upstreams.enumerated().mapAsync { @Sendable index, upstream in
                await upstream.tap { [weak self] in
                    await self?.setValue($0, forIndex: index)
                    await self?.sendValues()
                }
            }
        }
        
        /// Semantics of `CombineLatest`: Stream will have a current value as soon as any value could be obtained by all upstream Streams.
        public func currentValue() async -> V? {
            let receivedValues = latestValues.compactMap { $0 }
            guard receivedValues.count == latestValues.count else { return nil }
            return receivedValues
        }
        
        private func setValue(_ value: C.Element.V, forIndex index: Int) {
            latestValues[index] = value
        }
        
        private func sendValues() async {
            if let currentValue = await currentValue() {
                await send(currentValue)
            }
        }
    }
}

public extension Stream {
    func combineLatest<B: Stream>(_ other: B) async -> Streams.CombineLatest<Self, B> {
        await Streams.CombineLatest(self, other)
    }
    
    func combineLatest<B: Stream, C: Stream>(_ b: B, _ c: C) async -> Streams.CombineLatest3<Self, B, C> {
        await Streams.CombineLatest3(self, b, c)
    }
    
    func combineLatest<B: Stream, C: Stream, D: Stream>(_ b: B, _ c: C, _ d: D) async
    -> Streams.CombineLatest4<Self, B, C, D> {
        await Streams.CombineLatest4(self, b, c, d)
    }
    
    func combineLatest<B: Stream, C: Stream, D: Stream, E: Stream>(_ b: B, _ c: C, _ d: D, _ e: E) async
    -> Streams.CombineLatest5<Self, B, C, D, E> {
        await Streams.CombineLatest5(self, b, c, d, e)
    }
    
    func combineLatest<B: Stream, C: Stream, D: Stream, E: Stream, F: Stream>
    (_ b: B, _ c: C, _ d: D, _ e: E, _ f: F) async
    -> Streams.CombineLatest6<Self, B, C, D, E, F> {
        await Streams.CombineLatest6(self, b, c, d, e, f)
    }
    
    func combineLatest<B: Stream, C: Stream, D: Stream, E: Stream, F: Stream, G: Stream>
    (_ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) async
    -> Streams.CombineLatest7<Self, B, C, D, E, F, G> {
        await Streams.CombineLatest7(self, b, c, d, e, f, g)
    }
}

public extension Streams {
    static func combineLatest<A: Stream, B: Stream>(_ a: A, _ b: B) async -> CombineLatest<A, B> {
        await CombineLatest(a, b)
    }
    
    static func combineLatest<A: Stream, B: Stream, C: Stream>(_ a: A, _ b: B, _ c: C)
    async -> CombineLatest3<A, B, C> {
        await CombineLatest3(a, b, c)
    }
    
    static func combineLatest<A: Stream, B: Stream, C: Stream, D: Stream>(_ a: A, _ b: B, _ c: C, _ d: D)
    async -> CombineLatest4<A, B, C, D> {
        await CombineLatest4(a, b, c, d)
    }
    
    static func combineLatest<A: Stream, B: Stream, C: Stream, D: Stream, E: Stream>
    (_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) async -> CombineLatest5<A, B, C, D, E> {
        await CombineLatest5(a, b, c, d, e)
    }
    
    static func combineLatest<A: Stream, B: Stream, C: Stream, D: Stream, E: Stream, F: Stream>
    (_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) async -> CombineLatest6<A, B, C, D, E, F> {
        await CombineLatest6(a, b, c, d, e, f)
    }
    
    static func combineLatest<A: Stream, B: Stream, C: Stream, D: Stream, E: Stream, F: Stream, G: Stream>
    (_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) async -> CombineLatest7<A, B, C, D, E, F, G> {
        await CombineLatest7(a, b, c, d, e, f, g)
    }
}

public extension Streams.SendableTuple {
    var tupleValue: (A, B) { (a, b) }
}

public extension Collection where Element: Stream, Self: Sendable {
    func combineLatest() async -> Streams.CombineLatestCollection<Self> {
        await .init(upstreams: self)
    }
}

public extension Streams.SendableTuple where A: Equatable, B: Equatable {
    static func == (lhs: Streams.SendableTuple<A, B>, rhs: Streams.SendableTuple<A, B>) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b
    }
}

public extension Streams.SendableTuple3 where A: Equatable, B: Equatable, C: Equatable {
    static func == (lhs: Streams.SendableTuple3<A, B, C>, rhs: Streams.SendableTuple3<A, B, C>) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c
    }
}

public extension Streams.SendableTuple4 where A: Equatable, B: Equatable, C: Equatable, D: Equatable {
    static func == (lhs: Streams.SendableTuple4<A, B, C, D>, rhs: Streams.SendableTuple4<A, B, C, D>) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d
    }
}
