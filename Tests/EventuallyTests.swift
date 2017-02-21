//
//  EventuallyTests.swift
//  EventuallyTests
//
//  Created by Johan Sørensen on 21/02/2017.
//  Copyright © 2017 NRK. All rights reserved.
//

import XCTest
import Eventually

class EventuallyTests: XCTestCase {
    func testBasics() {
        let stringFuture = Future<String> { resolve in
            resolve(.success("hello"))
        }

        XCTAssert(stringFuture.isCompleted)
        switch stringFuture.value! {
        case .success(let value):
            XCTAssertEqual(value, "hello")
        case .failure:
            XCTFail()
        }
    }

    func testThen() {
        successFuture().then { result in
            switch result {
            case .success(let value):
                XCTAssertEqual(value, 42)
            case .failure:
                XCTFail()
            }
        }

        failingFuture().then { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(let error):
                XCTAssert(error is TestError)
            }
        }
    }

    func testAsyncSuccess() {
        let wait = expectation(description: "async")

        successAsyncFuture().then { result in
            XCTAssertEqual(result.value, Optional(42))
            XCTAssertNil(result.error)
            wait.fulfill()
        }
        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testSuccessFailureSugar() {
        let wait = expectation(description: "async")

        successAsyncFuture()
            .success { value in
                XCTAssertEqual(value, 42)
                wait.fulfill()
            }.failure { _ in
                XCTFail("should never be reached")
            }
        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testFailingSuccessFailureSugar() {
        let wait = expectation(description: "async")

        failingAsyncFuture()
            .success { _ in
                XCTFail("should never be reached")
            }.failure { error in
                XCTAssert(error is TestError)
                wait.fulfill()
        }
        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testAsyncFailure() {
        let wait = expectation(description: "async")

        failingAsyncFuture().then { result in
            XCTAssertNil(result.value)
            XCTAssertNotNil(result.error)
            wait.fulfill()
        }
        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testResolvingOnNonMailExecutionContext() {
        let future = Future<Int>(on: .background) { resolve in
            XCTAssertFalse(Thread.isMainThread)
            self.operation(completion: { val in
                resolve(.success(val))
            })
        }

        let wait = expectation(description: "async")

        future.then { result in
            XCTAssertTrue(Thread.isMainThread)
            wait.fulfill()
        }
        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testFulfillingMailExecutionContext() {
        let future = Future<Int>(on: .main) { resolve in
            XCTAssertTrue(Thread.isMainThread)
            self.operation(completion: { val in
                resolve(.success(val))
            })
        }

        let wait = expectation(description: "async")

        future.then(on: .background) { result in
            XCTAssertFalse(Thread.isMainThread)
            wait.fulfill()
        }
        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testAsyncMapping() {
        let wait = expectation(description: "async")

        successAsyncFuture()
            .map({ $0 * 2 })
            .then({ result in
                XCTAssertEqual(result.value, Optional(84))
                wait.fulfill()
            })

        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testAsyncMappingOnContext() {
        let wait = expectation(description: "async")

        successAsyncFuture()
            .map(on: .background, { (value: Int) -> Int in
                XCTAssertFalse(Thread.isMainThread)
                return value * 2
            })
            .then({ result in
                XCTAssertEqual(result.value, Optional(84))
                wait.fulfill()
            })

        waitForExpectations(timeout: 0.5, handler: nil)
    }

    // MARK: - Helpers

    func operation(completion: @escaping (Int) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(256)) {
            completion(42)
        }
    }

    func successAsyncFuture() -> Future<Int> {
        return Future { resolve in
            self.operation(completion: { val in
                resolve(.success(val))
            })
        }
    }

    func successFuture() -> Future<Int> {
        return Future { resolve in
            resolve(.success(42))
        }
    }

    enum TestError: Error {
        case fail
    }

    func failingFuture() -> Future<Int> {
        return Future<Int> { resolve in
            resolve(.failure(TestError.fail))
        }
    }

    func failingAsyncFuture() -> Future<Int> {
        return Future<Int> { resolve in
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(256)) {
                resolve(.failure(TestError.fail))
            }
        }
    }
}