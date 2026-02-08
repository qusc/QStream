# QStream

A reactive framework for Swift built on structured concurrency. Designed for observing and transforming state — not processing sequences of events.

## Quick Look

```swift
let isConnected: Subject<Bool> = .init(value: false)
let userName: Subject<String> = .init(value: "")

var subscriptions: [AnySubscription] = []

// Derive a status label from two streams — with async closures
await isConnected.combineLatest(userName)
    .map { connected, name in connected ? "Online: \(name)" : "Offline" }
    .removeDuplicates()
    .tap { label in print(label) }
    .store(in: &subscriptions)

await isConnected.set(true)   // "Online: "
await userName.set("Alice")   // "Online: Alice"
```

Every `Stream` is an actor. Every operator closure is `async`. Values are buffered at every point in the chain, so any derived stream can report its `currentValue()` at any time.

## Why QStream?

Combine and RxSwift try to solve two very different problems with one abstraction:

1. **Processing sequences of values** (e.g., chunks of data when downloading a file) — requires completion events, error types, and per-subscriber operator chains that bubble upstream.
2. **Observing the current value of a variable** — only the latest value matters, every point in the chain can buffer, and multiple subscribers just read the same cached result.

Modern Swift already handles (1) well with `AsyncSequence` and `AsyncStream`. But (2) — reactive state observation — still doesn't have a great native solution:

- **Combine** doesn't support `async` closures in operators, delivers values to subscribers in non-deterministic order, and carries the complexity of a sequence-processing framework (completion events, error types, cold vs. hot publishers) even when you just want to observe state.
- **Swift Observation** has pull semantics, requires a running `Task` per observation, and doesn't support async transformations — it's tailored to SwiftUI view updates, not general-purpose state propagation across services and view models.

QStream is a simpler reactive framework built specifically for use case (2).

## Features

- **Async/await native** — all operator closures are `async`, no callback gymnastics
- **Actor-based** — every stream is an actor, thread-safe by construction
- **Current value semantics** — values are buffered (multicast) at every operator, not just at the source
- **Guaranteed ordering** — values are processed in the order they're sent, enforced via `AsyncBinarySemaphore`
- **Lightweight** — no completion events, no error types, no cold/hot distinction
- **40+ operators** — `map`, `compactMap`, `filter`, `combineLatest` (2–7 upstreams), `switchToLatest`, `debounce`, `throttle`, `merge`, `scan`, `flatMap`, `removeDuplicates`, and more

## Installation

Add QStream to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/qusc/QStream.git", branch: "main")
]
```

```swift
.target(
    name: "YourTarget",
    dependencies: ["QStream"]
)
```

**Requirements:** Swift 6.2+, macOS 15+ / iOS 17+ / watchOS 10+

## Core Types

### Subject

A mutable stream that holds a current value — the primary building block for observable state.

```swift
let count: Subject<Int> = .init(value: 0)

await count.set(42)
await count.value  // 42

// Mutate in-place and re-emit
await count.mutate { $0 += 1 }
```

### Relay

A stateless stream with no current value — for fire-and-forget events.

```swift
let buttonTapped: Relay<Void> = .init()

await buttonTapped.send(())
```

### AnyStream

A type-erased wrapper, created with `.any()`.

```swift
func userStatus() async -> AnyStream<String> {
    await isConnected
        .map { $0 ? "Online" : "Offline" }
        .any()
}
```

## Subscribing

**`tap`** delivers the current value immediately (if one exists), then all future values:

```swift
await count
    .tap { value in
        print(value) // prints current value, then every update
    }
    .store(in: &subscriptions)
```

**`subscribe`** delivers only future values:

```swift
await count
    .subscribe { value in
        print(value) // prints only new values after subscribing
    }
    .store(in: &subscriptions)
```

Subscriptions are retained by storing them. When the subscription object is deallocated, the binding is automatically cleaned up.

```swift
var subscriptions: [AnySubscription] = []
```

## Operators

All operators support `async` closures.

### Transforming

```swift
await stream.map { value in await transform(value) }
await stream.compactMap { value in await optionalTransform(value) }
await stream.flatMap { value in await arrayTransform(value) }
await stream.scan(initialValue) { accumulated, next in await reduce(accumulated, next) }
```

### Filtering

```swift
await stream.filter { value in await shouldInclude(value) }
await stream.removeDuplicates()
await stream.removeDuplicates(by: { await $0.id == $1.id })
await stream.first()
```

### Combining

```swift
// Combine latest values from multiple streams (2-7 overloads + collection)
await streamA.combineLatest(streamB)
    .map { a, b in "\(a): \(b)" }

// Merge multiple streams of the same type
await Streams.Merge(streamA, streamB, streamC)

// Switch to the latest inner stream
await outerStream
    .map { item in await item.innerStream.any() }
    .switchToLatest()
```

### Timing

```swift
await stream.debounce(for: .seconds(0.3))
await stream.throttle(for: .seconds(1))
await boolStream.hold(for: .seconds(2))
let timer = await Streams.Timer(interval: .seconds(1))
```

### Utility

```swift
await stream.any()                                   // Type-erase
await stream.print("label")                          // Debug logging
await stream.dispatch()                              // Move processing off the current actor
await stream.bind(to: someSubject)                   // Pipe values into a Subject or Relay
let value = await stream.get()                       // Await the next value
let value = try await stream.get(timeout: .seconds(5))
await stream.with(initialValue: defaultValue)        // Prepend an initial value
```

## Mental Model

Think of streams as electrical wires. A `Subject` holds a voltage (the current value); a `Relay` carries impulse signals. Operators are circuit components that transform, filter, or combine signals in real time.

Streams have **no memory** — they don't replay past values to new subscribers. When you `tap` a stream, you get its current voltage (if any) and then every future change. If a value was sent before you connected, it's gone.

While QStream is designed for state observation, it works perfectly well for processing sequences of values too — as long as subscriptions are wired up before values start flowing upstream.

## Pitfalls

### Race conditions with value-dropping operators

Operators like `filter` and `compactMap` can drop a stream's current value, producing a stream that may or may not have a value at any given moment. This creates a subtle race condition: if you `tap` such a stream, you might or might not receive a current value depending on timing.

```swift
// Risky — the compactMap stream has no guaranteed current value,
// so a tap might miss the initial state entirely:
await optionalUserStream
    .compactMap { $0 }
    .tap { user in updateUI(user) }
    .store(in: &subscriptions)

// Safer — forward optionals and handle nil explicitly:
await optionalUserStream
    .tap { user in updateUI(user) }  // receives Optional<User>, always has a current value
    .store(in: &subscriptions)
```

**Recommendation:** Prefer propagating optional values through the chain and handling `nil` explicitly in the subscriber, rather than using `compactMap` to strip optionals — unless you can guarantee that all subscriptions are in place before the upstream starts emitting.

### Deadlocks from upstream sends inside subscribers

When you call `.set()` or `.send()` on a `Subject`, the call blocks until **all** downstream subscribers have processed the value, in subscription order (unless a `.dispatch()` breaks the synchronous chain). This means that if a subscriber tries to `.set()` a value back on an upstream stream, it will deadlock — the upstream send can't complete because it's waiting for the subscriber, and the subscriber can't complete because it's waiting for the upstream.

```swift
let a: Subject<Int> = .init(value: 0)
let b: Subject<Int> = .init(value: 0)

// This will deadlock — a's send waits for this subscriber,
// which waits for b's send, which (if b feeds back into a) waits for a:
await a.tap { value in
    await b.set(value + 1)  // blocks until b's subscribers finish
}.store(in: &subscriptions)
```

In DEBUG builds, QStream's `AsyncBinarySemaphore` has built-in deadlock detection that triggers a `fatalError` when it detects a single-task deadlock (i.e., a task trying to acquire a semaphore it already holds). This won't catch all deadlock scenarios (e.g., cross-task cycles), but it catches the most common case and gives you a clear crash instead of a silent hang.

**Solutions:** Use `.dispatch()` to break the synchronous chain before sending values back upstream, or restructure the data flow to avoid circular dependencies.

## More Examples

### Dynamic Stream Switching

```swift
let activeSource: Subject<AudioSource?> = .init(value: nil)

await activeSource
    .map { source in await source?.volume.any() ?? Subject(value: 0.0).any() }
    .switchToLatest()
    .removeDuplicates()
    .tap { volume in print("Volume: \(volume)") }
    .store(in: &subscriptions)
```

## Async Utilities

QStream also ships with general-purpose async helpers:

```swift
// Async sequence operations
let results = await items.mapAsync { await process($0) }
let filtered = await items.filterAsync { await shouldKeep($0) }
await items.forEachConcurrent { await handle($0) }

// Task helpers
let value = try await Task.withTimeout(.seconds(10)) { await longOperation() }
let (a, b) = try await Task.all(of: taskA, taskB)

// Synchronization
let semaphore = AsyncBinarySemaphore()
let result = await semaphore.withLock { await criticalSection() }
```

### AsyncBinarySemaphore

An async/await-compatible binary semaphore that doubles as a mutex and a signal. Swift's actors serialize access to their own state, but they don't help when you need to serialize a multi-step async operation across suspension points — or coordinate between a producer and a consumer. `AsyncBinarySemaphore` fills that gap.

**As a lock** — serialize async operations that must not run concurrently:

```swift
let sendMessageLock: AsyncBinarySemaphore = .init()

func sendMessage(_ message: Message) async throws {
    try await sendMessageLock.withLock {
        try await encryptAndSend(message)  // only one send at a time
    }
}
```

**As a signal** — producer/consumer coordination:

```swift
let dataAvailable: AsyncBinarySemaphore = .init(value: false)  // starts unavailable

// Producer
func push(buffer: AVAudioPCMBuffer) async {
    inputQueue.append(buffer)
    await dataAvailable.signal()
}

// Consumer
func encodeLoop() async {
    while !Task.isCancelled {
        await dataAvailable.wait()  // suspends until signal
        let buffer = inputQueue.removeFirst()
        encode(buffer)
    }
}
```

**Cancelable waiting** — responds to task cancellation instead of hanging:

```swift
// Throws CancellationError if the task is cancelled while waiting
try await semaphore.withLockCancelable { await work() }
try await semaphore.waitCancelable()
```

**Task reentrancy** — allows the same task to re-acquire the lock without deadlocking (reentrant mutex):

```swift
let lock: AsyncBinarySemaphore = .init(allowTaskReentrancy: true)

await lock.withLock {
    // ...
    await lock.withLock {
        // same task, no deadlock
    }
}
```

## License

MIT License. See [LICENSE](LICENSE) for details.
