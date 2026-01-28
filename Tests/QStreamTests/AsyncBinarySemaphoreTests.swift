//
//  File.swift
//  
//
//  Created by Quirin Schweigert on 27.04.24.
//

import XCTest
@testable import QStream

final class AsyncBinarySemaphoreTests: XCTestCase {
    func testReentrancy() async throws {
        let semaphore = AsyncBinarySemaphore(allowTaskReentrancy: true)
        
        let expectation = self.expectation(description: "reentrancy was allowed")

        Task {
            await semaphore.withLock {
                await semaphore.withLock {
                    expectation.fulfill()
                }
            }
        }

        await fulfillment(of: [expectation], timeout: 1)
    }
    
    func testIsolation() async throws {
        let semaphore = AsyncBinarySemaphore(allowTaskReentrancy: true)

        let sharedFlag: ValueActor<Bool> = .init(value: false)

        let task1 = Task {
            try await semaphore.withLock {
                try await Task.sleep(timeInterval: .seconds(1))
                
                try await semaphore.withLock {
                    guard await !sharedFlag.value else { XCTFail(); return }
                    
                    await sharedFlag.set(value: true)
                    try await Task.sleep(timeInterval: .seconds(1))
                    await sharedFlag.set(value: false)
                }
            }
        }
        
        let task2 = Task {
            try await semaphore.withLock {
                guard await !sharedFlag.value else { XCTFail(); return }
                
                await sharedFlag.set(value: true)
                try await Task.sleep(timeInterval: .seconds(1))
                await sharedFlag.set(value: false)
            }
        }
        
        try await task1.value
        try await task2.value
    }
    
    func testIsolationCounter() async throws {
        let semaphore = AsyncBinarySemaphore()

        let sharedValue: ValueActor<Int> = .init(value: 0)
        let iterations = 10000
        let taskCount = 50

        let tasks = (0..<taskCount).map { index in
            Task {
                for _ in 0..<iterations {
                    await semaphore.withLock {
                        let value = await sharedValue.value
                        await sharedValue.set(value: value + 1)
                    }
                }
            }
        }
        
        await tasks.forEachAsync { await $0.value }
        
        let result = await sharedValue.value
        print("result: \(result)")
        
        XCTAssert(result == iterations * taskCount)
    }
}
