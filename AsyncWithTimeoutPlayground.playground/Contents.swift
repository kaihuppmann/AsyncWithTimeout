import UIKit

import Foundation


// MARK: - Implementation

enum AsyncError: Error {
    case timedOut(after: TimeInterval)
    case unknown(underlying: Error)
}

/**
 Starts the work (task) and a timout task and cancels the one, which takes longer.
 Returns result from worker task or throws `AsyncError.timeout`, when worker was cancelled.
 */
func async<T>(timeout: TimeInterval, work: @escaping() async -> T) async throws -> T {

    let workerTask = Task { () -> T in
        do {
            let result =  await work()
            if Task.isCancelled { // when it's cancelled, it's a timeout => throw AsyncError.timeout
                throw AsyncError.timedOut(after: timeout)
            }
            return result
        }
    }

    let timeoutTask = Task { () -> Void in
        do {
            try await Task.sleep(nanoseconds: UInt64(timeout) * 1_000_000_000)
            workerTask.cancel() // timeout reached => cancel the call (which will throw AsyncError.timeout then)
        } catch ( _ as CancellationError) {
            return // is expected behaviour
        } catch {
            throw AsyncError.unknown(underlying: error) 
        }
    }

    Task {
        try await workerTask.value // got a value => cancel the timeout
        timeoutTask.cancel()
    }

    return try await workerTask.value
}

// MARK: - Example Functions

/// asynchronous sample function that returns nil on error
func asyncOperation1() async -> Double? {
    do {
        try await Task.sleep(nanoseconds: 10_000_000_000) // just simulate a long calculation
        return 47.11
    } catch {
        return nil
    }
}

/// asynchronous sample function with result
func asyncOperation2(suffix: String) async -> (String?, Error?) {
    do {
        try await Task.sleep(nanoseconds: 10_000_000_000) // just simulate a long calculation
        return ("A String Result for " + suffix, nil)
    } catch {
        return (nil, error)
    }
}

/// asynchronous sample function that thows
func asyncOperation3() async throws -> Int {
    try await Task.sleep(nanoseconds: 10_000_000_000) // just simulate a long calculation
    return 17
}

/// asynchronous sample void function that thows
func asyncOperation4() async throws {
    try await Task.sleep(nanoseconds: 10_000_000_000) // just simulate a long calculation
}

// MARK: - Test Functions

/// test functions for different workers
func test1(timeout: TimeInterval) async {
    do {
        if let success = try await async(timeout: timeout, work: asyncOperation1) {
            print("1 Job Success: \(success)")
        } else {
            print("1 Job Fail")
        }
    } catch (let asyncError as AsyncError) {
        print("1 Job Async Error: \(asyncError)")
    } catch {
        print("1 Job Some Other Error: \(error)")
    }
}

func test2(timeout: TimeInterval) async {
    do {
        let result = try await async(timeout: timeout) {
            return await asyncOperation2(suffix: "Kai")
        }
        if let fail = result.1 {
            print("2 Fail: \(fail)")
        } else if let success = result.0 {
            print("2 Success: \(success)")
        }
    } catch (let asyncError as AsyncError) {
        print("2 Async Error: \(asyncError)")
    } catch {
        print("2  Some Other Error: \(error)")
    }
}

func test3(timeout: TimeInterval) async {
    do {
        let result: (Int?, Error?) = try await async(timeout: timeout) {
            do {
                return try await (asyncOperation3(), nil)
            } catch {
                return (nil, error)
            }
        }
        if let fail = result.1 {
            print("3 Job Fail: \(fail)")
        } else if let success = result.0 {
            print("3 Job Success: \(success)")
        }
    } catch (let asyncError as AsyncError) {
        print("3 Job Async Error: \(asyncError)")
    } catch {
        print("3 Job Some Other Error: \(error)")
    }
}

func test4(timeout: TimeInterval) async {
    do {
        try await async(timeout: timeout) {
            do {
                try await asyncOperation4()
                print("4 Job Success")
            } catch {}
        }
    } catch (let asyncError as AsyncError) {
        print("4 Job Async Error: \(asyncError)")
    } catch {
        print("4 Job Some Other Error: \(error)")
    }
}

// MARK: - Tests

// test with loooong timeout
// funny enough these do not work with
// timeout ≤ 10.9 sometimes, but always with ≥ 11 ... ¯\_(ツ)_/¯
Task {
    await test1(timeout: 11)
}
Task {
    await test2(timeout: 11)
}
Task {
    await test3(timeout: 11)
}
Task {
    await test4(timeout: 11)
}

// test with short timeout
Task {
    await test1(timeout: 8.5)
}
Task {
    await test2(timeout: 2.3)
}
Task {
    await test3(timeout: 6.7)
}
Task {
    await test4(timeout: 4.6)
}
