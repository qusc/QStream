import XCTest
@testable import QStream

final class QStreamTests: XCTestCase {
    func testSubject() throws {
        let initialValueExpectation = self.expectation(description: "Value did send inital value")
        let sentValueExpectation = self.expectation(description: "Value did send inital value")
        
        Task {
            var subscriptions: [AnySubscription] = []
            
            let didReceiveInitialValue: ValueActor<Bool> = .init(value: false)
            
            let subject: Subject<String> = .init(value: "Initial")
            
            await subject
                .tap {
                    if $0 == "Initial" {
                        initialValueExpectation.fulfill()
                        let didReceiveInitialValue_ = await didReceiveInitialValue.value
                        XCTAssert(!didReceiveInitialValue_)
                        await didReceiveInitialValue.set(value: true)
                    } else if $0 == "Test" {
                        let didReceiveInitialValue_ = await didReceiveInitialValue.value
                        XCTAssert(didReceiveInitialValue_)
                        sentValueExpectation.fulfill()
                    } else {
                        XCTAssert(false)
                    }
                }
                .store(in: &subscriptions)
            
            await subject.set("Test")
        }
        
        wait(for: [initialValueExpectation, sentValueExpectation], timeout: 1)
    }
    
    func testMultipleTaps() {
        let valueAReceivedExpecation = self.expectation(description: "tap A did receive value")
        let valueBReceivedExpecation = self.expectation(description: "tap B did receive value")
        
        Task {
            var subscriptions: [AnySubscription] = []
            
            let stream: AnyStream<Bool> = await Subject(value: true)
                .map { $0 }
                .any()
            
            await stream
                .tap { _ in
                    valueAReceivedExpecation.fulfill()
                }
                .store(in: &subscriptions)
            
            await stream
                .tap { _ in
                    valueBReceivedExpecation.fulfill()
                }
                .store(in: &subscriptions)
        }
        
        wait(for: [valueAReceivedExpecation, valueBReceivedExpecation], timeout: 1)
    }

    func testMap() throws {
        let expectation = self.expectation(description: "Mapped values were emitted")
        
        Task {
            var subscriptions: [AnySubscription] = []
            
            let testValues = 0...10
            
            let mappedValuesActor: ValueActor<[Int]> = .init(value: [])
            
            let relay: Relay<Int> = .init()
            
            await relay
                .map { $0 * 2 }
                .tap {
                    await mappedValuesActor.set(value: mappedValuesActor.value + [$0])
                    
                    if await mappedValuesActor.value == testValues.map({ $0 * 2 }) {
                        expectation.fulfill()
                    }
                }
                .store(in: &subscriptions)
            
            for value in testValues {
                await relay.send(value)
            }
        }
        
        wait(for: [expectation], timeout: 1)
    }

    func testCompactMap() throws {
        let expectation = self.expectation(description: "Mapped values were emitted")
        
        Task {
            var subscriptions: [AnySubscription] = []
            
            let testValues = 0...10
            
            actor TestActor {
                var mappedValues: [Int] = []
                func append(value: Int) { mappedValues.append(value) }
            }
            
            let testActor: TestActor = .init()
            
            let relay: Relay<Int> = .init()
            
            await relay
                .compactMap { $0 % 2 == 0 ? $0 * 2 : nil }
                .tap {
                    await testActor.append(value: $0)
                    
                    if await testActor.mappedValues == testValues.compactMap({ $0 % 2 == 0 ? $0 * 2 : nil }) {
                        expectation.fulfill()
                    }
                }
                .store(in: &subscriptions)
            
            for value in testValues {
                await relay.send(value)
            }
        }
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testDebounce() {
        let expectation = self.expectation(description: "Debounced values were emitted")
        let noErrorExpectation = self.expectation(description: "No errors occured during wait")
        
        Task {
            var subscriptions: [AnySubscription] = []
            
            typealias TestValue = Int
            let relay: Relay<TestValue> = .init()
            
            struct ScheduledValue: Sendable {
                let value: TestValue
                let delay: DispatchTimeInterval
            }
            
            let debounceInterval: DispatchTimeInterval = .seconds(1)
            
            let testValues: [ScheduledValue] = [
                .init(value: 1, delay: .milliseconds(0)),
                .init(value: 2, delay: .milliseconds(200)),
                .init(value: 3, delay: .milliseconds(1300)),
                .init(value: 4, delay: .milliseconds(3000)),
                .init(value: 5, delay: .milliseconds(3050)),
                .init(value: 6, delay: .milliseconds(3100)),
            ]
            
            let expectedDebouncedValues: ValueActor<[ScheduledValue]> = .init(value: [
                .init(value: 2, delay: .milliseconds(1200)),
                .init(value: 3, delay: .milliseconds(2300)),
                .init(value: 6, delay: .milliseconds(4100)),
            ])
            
            let allowedLeeway: DispatchTimeInterval = .milliseconds(100) // apparently Task.sleep() isn't very accurate
            
            let startTime: DispatchTime = .now()
            
            testValues.forEach { testValue in
                Task {
                    try! await Task.sleep(nanoseconds: UInt64(testValue.delay.totalNanoseconds))
                    await relay.send(testValue.value)
                }
            }
            
            await relay
                .tap {
                    print("relay receive \($0) at \(startTime.distance(to: .now()).totalNanoseconds / 1_000_000)ms")
                }
                .store(in: &subscriptions)
            
            await relay
                .debounce(for: debounceInterval)
                .tap { receivedValue in
                    let measuredReceiveTime = startTime.distance(to: .now())
                    print("debounce receive \(receivedValue) at \(measuredReceiveTime.totalNanoseconds / 1_000_000)ms")
                    
                    guard await !expectedDebouncedValues.value.isEmpty else {
                        XCTFail("Debounce received too many values")
                        return
                    }
                    
                    let expectedValue = await expectedDebouncedValues.execute({ $0.removeFirst() })
                    
                    guard receivedValue == expectedValue.value else {
                        XCTFail("Debounce received wrong value")
                        return
                    }
                    
                    let timeDeltaNanoseconds =
                    abs(Int64(measuredReceiveTime.totalNanoseconds) - Int64(expectedValue.delay.totalNanoseconds))
                    
                    guard timeDeltaNanoseconds <= allowedLeeway.totalNanoseconds else {
                        XCTFail("Debounce missed allowed leeway by \(timeDeltaNanoseconds - allowedLeeway.totalNanoseconds)ns")
                        return
                    }
                    
                    if await expectedDebouncedValues.value.isEmpty {
                        expectation.fulfill()
                    }
                }
                .store(in: &subscriptions)
            
            try! await Task.sleep(timeInterval: 10)
            noErrorExpectation.fulfill()
        }
        
        wait(for: [expectation, noErrorExpectation], timeout: 11)
    }
    
    func testThrottle() {
        let expectation = self.expectation(description: "Throttled values were emitted")
        let noErrorExpectation = self.expectation(description: "No errors occured during wait")
        
        Task {
            var subscriptions: [AnySubscription] = []
            
            typealias TestValue = Int
            let relay: Relay<TestValue> = .init()
            
            struct ScheduledValue: Sendable {
                let value: TestValue
                let delay: DispatchTimeInterval
            }
            
            let throttleInterval: DispatchTimeInterval = .seconds(1)
            
            let testValues: [ScheduledValue] = [
                .init(value: 1, delay: .milliseconds(0)),
                .init(value: 2, delay: .milliseconds(100)),
                .init(value: 3, delay: .milliseconds(1200)),
                .init(value: 4, delay: .milliseconds(3000)),
                .init(value: 5, delay: .milliseconds(3050)),
                .init(value: 6, delay: .milliseconds(3100)),
            ]
            
            let expectedThrottledValues: ValueActor<[ScheduledValue]> = .init(value: [
                .init(value: 1, delay: .milliseconds(0)),
                .init(value: 2, delay: .milliseconds(1000)),
                .init(value: 3, delay: .milliseconds(2000)),
                .init(value: 4, delay: .milliseconds(3000)),
                .init(value: 6, delay: .milliseconds(4000)),
            ])
            
            let allowedLeeway: DispatchTimeInterval = .milliseconds(200) // apparently Task.sleep() isn't very accurate
            
            let startTime: DispatchTime = .now()
            
            testValues.forEach { testValue in
                Task {
                    try! await Task.sleep(nanoseconds: UInt64(testValue.delay.totalNanoseconds))
                    await relay.send(testValue.value)
                }
            }
            
            await relay
                .tap {
                    print("relay receive \($0) at \(startTime.distance(to: .now()).totalNanoseconds / 1_000_000)ms")
                }
                .store(in: &subscriptions)
            
            await relay
                .throttle(for: throttleInterval)
                .tap { receivedValue in
                    let measuredReceiveTime = startTime.distance(to: .now())
                    print("throttle receive \(receivedValue) at \(measuredReceiveTime.totalNanoseconds / 1_000_000)ms")
                    
                    guard await !expectedThrottledValues.value.isEmpty else {
                        XCTFail("throttle received too many values")
                        return
                    }
                    
                    let expectedValue = await expectedThrottledValues.execute({ $0.removeFirst() })
                    
                    guard receivedValue == expectedValue.value else {
                        XCTFail("throttle received wrong value")
                        return
                    }
                    
                    let timeDeltaNanoseconds =
                    abs(Int64(measuredReceiveTime.totalNanoseconds) - Int64(expectedValue.delay.totalNanoseconds))
                    
                    guard timeDeltaNanoseconds <= allowedLeeway.totalNanoseconds else {
                        XCTFail("throttle missed allowed leeway by \((timeDeltaNanoseconds - allowedLeeway.totalNanoseconds) / 1_000_000)ms")
                        return
                    }
                    
                    if await expectedThrottledValues.value.isEmpty {
                        expectation.fulfill()
                    }
                }
                .store(in: &subscriptions)
            
            try! await Task.sleep(timeInterval: 10)
            noErrorExpectation.fulfill()
        }
        
        wait(for: [expectation, noErrorExpectation], timeout: 11)
    }
    
    func testSwitchToLatest() {
        let expectation = self.expectation(description: "Correct values were emitted")
        let noErrorExpectation = self.expectation(description: "No errors occured during wait")

        Task {
            var subscriptions: [AnySubscription] = []

            typealias TestValue = Int

            struct ScheduledValue: Sendable {
                let value: TestValue
                let delay: DispatchTimeInterval
            }

            let testValuesA: [ScheduledValue] = [
                .init(value: 1, delay: .milliseconds(0)),
                .init(value: 2, delay: .milliseconds(100)),
                .init(value: 3, delay: .milliseconds(1200))
            ]
            
            let testValuesB: [ScheduledValue] = [
                .init(value: 1, delay: .milliseconds(200)),
                .init(value: 2, delay: .milliseconds(2000)),
                .init(value: 3, delay: .milliseconds(2500))
            ]
            
            let switchTime: DispatchTimeInterval = .milliseconds(1000)
            

            let expectedOutputValues: ValueActor<[ScheduledValue]> = .init(value: [
                .init(value: 1, delay: .milliseconds(0)),
                .init(value: 2, delay: .milliseconds(100)),
                .init(value: 1, delay: .milliseconds(1000)),
                .init(value: 2, delay: .milliseconds(2000)),
                .init(value: 3, delay: .milliseconds(2500)),
            ])

            let allowedLeeway: DispatchTimeInterval = .milliseconds(200) // apparently Task.sleep() isn't very accurate

            let startTime: DispatchTime = .now()

            let subjectA: Subject<TestValue?> = .init(value: nil)
            let subjectB: Subject<TestValue?> = .init(value: nil)
            
            testValuesA.forEach { testValue in
                Task {
                    try! await Task.sleep(nanoseconds: UInt64(testValue.delay.totalNanoseconds))
                    await subjectA.set(testValue.value)
                }
            }
            
            testValuesB.forEach { testValue in
                Task {
                    try! await Task.sleep(nanoseconds: UInt64(testValue.delay.totalNanoseconds))
                    await subjectB.set(testValue.value)
                }
            }
            
            let streamsOfStreams: Subject<AnyStream<TestValue>> = await .init(value: subjectA.compactMap().any())
            
            
            Task {
                try! await Task.sleep(nanoseconds: UInt64(switchTime.totalNanoseconds))
                await streamsOfStreams.send(subjectB.compactMap().any())
            }
            
            let outputStream = await streamsOfStreams.switchToLatest()

            await outputStream
                .tap { receivedValue in
                    let measuredReceiveTime = startTime.distance(to: .now())
                    print("output receive \(receivedValue) at \(measuredReceiveTime.totalNanoseconds / 1_000_000)ms")

                    guard await !expectedOutputValues.value.isEmpty else {
                        XCTFail("received too many values after switchToLatest()")
                        return
                    }

                    let expectedValue = await expectedOutputValues.execute({ $0.removeFirst() })

                    guard receivedValue == expectedValue.value else {
                        XCTFail("received wrong value after switchToLatest(): \(receivedValue)")
                        return
                    }

                    let timeDeltaNanoseconds =
                    abs(Int64(measuredReceiveTime.totalNanoseconds) - Int64(expectedValue.delay.totalNanoseconds))

                    guard timeDeltaNanoseconds <= allowedLeeway.totalNanoseconds else {
                        XCTFail("missed allowed leeway by \((timeDeltaNanoseconds - allowedLeeway.totalNanoseconds) / 1_000_000)ms")
                        return
                    }

                    if await expectedOutputValues.value.isEmpty {
                        expectation.fulfill()
                    }
                }
                .store(in: &subscriptions)

            try! await Task.sleep(timeInterval: 5)
            noErrorExpectation.fulfill()
        }

        wait(for: [expectation, noErrorExpectation], timeout: 11)
    }
    
    func testMapToLatest() {
        let expectation = self.expectation(description: "Correct values were emitted")
        let noErrorExpectation = self.expectation(description: "No errors occured during wait")
        
        Task {
            var subscriptions: [AnySubscription] = []
            
            typealias TestValue = Int
            
            struct ScheduledValue: Sendable {
                let value: TestValue
                let delay: DispatchTimeInterval
            }
            
            let testValuesA: [ScheduledValue] = [
                .init(value: 1, delay: .milliseconds(0)),
                .init(value: 2, delay: .milliseconds(600)),
                .init(value: 3, delay: .milliseconds(1200))
            ]
            
            let testValuesB: [ScheduledValue] = [
                .init(value: 1, delay: .milliseconds(200)),
                .init(value: 2, delay: .milliseconds(2000)),
                .init(value: 3, delay: .milliseconds(2500))
            ]
            
            let switchTimeA: DispatchTimeInterval = .milliseconds(300)
            let switchTimeB: DispatchTimeInterval = .milliseconds(1000)
            
            let expectedOutputValues: ValueActor<[ScheduledValue]> = .init(value: [
                .init(value: 2, delay: .milliseconds(600)),
                .init(value: 2, delay: .milliseconds(2000)),
                .init(value: 3, delay: .milliseconds(2500)),
            ])
            
            let allowedLeeway: DispatchTimeInterval = .milliseconds(200) // apparently Task.sleep() isn't very accurate
            
            let startTime: DispatchTime = .now()
            
            let relayA: Relay<TestValue> = .init()
            let relayB: Relay<TestValue> = .init()
            
            testValuesA.forEach { testValue in
                Task {
                    try! await Task.sleep(nanoseconds: UInt64(testValue.delay.totalNanoseconds))
                    await relayA.send(testValue.value)
                }
            }
            
            testValuesB.forEach { testValue in
                Task {
                    try! await Task.sleep(nanoseconds: UInt64(testValue.delay.totalNanoseconds))
                    await relayB.send(testValue.value)
                }
            }
            
            let streamsOfStreams: Subject<Relay<TestValue>?> = .init(value: nil)
            
            Task {
                try! await Task.sleep(nanoseconds: UInt64(switchTimeA.totalNanoseconds))
                await streamsOfStreams.send(relayA)
            }
            
            Task {
                try! await Task.sleep(nanoseconds: UInt64(switchTimeB.totalNanoseconds))
                await streamsOfStreams.send(relayB)
            }
            
            let outputStream = await streamsOfStreams.map { $0 ?? Relay() }.any()
            
            await outputStream
                .switchToLatest()
                .tap { receivedValue in
                    let measuredReceiveTime = startTime.distance(to: .now())
                    print("output receive \(receivedValue) at \(measuredReceiveTime.totalNanoseconds / 1_000_000)ms")
                    
                    guard await !expectedOutputValues.value.isEmpty else {
                        XCTFail("throttle received too many values")
                        return
                    }
                    
                    let expectedValue = await expectedOutputValues.execute({ $0.removeFirst() })
                    
                    guard receivedValue == expectedValue.value else {
                        XCTFail("throttle received wrong value")
                        return
                    }
                    
                    let timeDeltaNanoseconds =
                    abs(Int64(measuredReceiveTime.totalNanoseconds) - Int64(expectedValue.delay.totalNanoseconds))
                    
                    guard timeDeltaNanoseconds <= allowedLeeway.totalNanoseconds else {
                        XCTFail("throttle missed allowed leeway by \((timeDeltaNanoseconds - allowedLeeway.totalNanoseconds) / 1_000_000)ms")
                        return
                    }
                    
                    if await expectedOutputValues.value.isEmpty {
                        expectation.fulfill()
                    }
                }
                .store(in: &subscriptions)
            
            try! await Task.sleep(timeInterval: 5)
            noErrorExpectation.fulfill()
        }
        
        wait(for: [expectation, noErrorExpectation], timeout: 11)
    }
    
    func testGetTimeout() {
        let timeoutExpectation = self.expectation(description: "Timeout worked")
        let valueExpectation = self.expectation(description: "Value was emitted")

        let testRelay: Relay<String> = .init()
        
        Task {
            try await Task.sleep(timeInterval: .seconds(1))
            await testRelay.send("Completion 1!")
        }
        
        Task {
            let result = try? await testRelay.get(timeout: .seconds(2))
            XCTAssert(result == "Completion 1!")
            valueExpectation.fulfill()
        }
        
        Task {
            let result = try? await testRelay.get(timeout: .milliseconds(500))
            XCTAssert(result == nil)
            timeoutExpectation.fulfill()
        }
        
        wait(for: [timeoutExpectation, valueExpectation], timeout: 5)
    }
    
    func testForEachConcurrent() {
        let values = 1...3
        let expectations = values.map { ($0, self.expectation(description: "Task \($0) completed")) }
        
        Task {
            print("starting tasks")
            
            await expectations.forEachConcurrent { value, expectation in
                print("Task \(value) started")
                try? await Task.sleep(timeInterval: TimeInterval(value))
                print("Task \(value) completed")
                expectation.fulfill()
            }
            
            print("all tasks completed")
        }
        
        wait(for: expectations.map { $0.1 }, timeout: TimeInterval(values.max() ?? 0) + 1)
    }
}
