//
//  Future.swift
//  Eventually
//
//  Created by Johan Sørensen on 21/02/2017.
//  Copyright © 2017 NRK. All rights reserved.
//

import Foundation

public final class Future<Value> {
    public typealias Resolver = (@escaping (FutureResult<Value>) -> Void) -> Void

    public var value: FutureResult<Value>?
    public var isCompleted: Bool { return value != nil }

    private var observers: [Observable<Value>] = []
    private let observationQueue = DispatchQueue(label: "no.nrk.Eventually.observations", qos: .background)

    /// Creates a new future, call the provided resolver when the (async) task completes with
    /// either an FutureResult.success or FutureResult.failure in the case of errors
    ///
    /// - returns: a Future which can be passed around, mapped to another type or materialize its value once
    ///            the value is available
    /// - parameter on: The ExecutionContext on which this Future should be resolved. Defaults to main queue
    /// - parameter resolver: The body of the Future which received a resolve closure to be called 
    ///                       when the Future is realized
    ///
    /// ```swift
    /// Future<Int> { resolve in
    ///     someAsyncFunc { value in
    ///         resolve(.success(value))
    ///     }
    /// }
    public init(on context: ExecutionContext = .main, resolver: @escaping Resolver) {
        self.value = nil

        context.apply {
            resolver { val in
                self.complete(with: val)
            }
        }
    }

    /// Calls the completion closure once the value of the Future is available to be materialized
    ///
    /// - parameter on: The ExecutionContext on which the completion closure should be called, defaults to .main
    /// - parameter completion: The closure which will receive the FutureResult once the Future is materialized
    /// - returns: A new chainable Future instance
    ///
    /// ```swift
    /// someFuture.then { result in
    /// switch result {
    /// case .success(let value):
    ///     // .. do something with the Value
    /// case .failure(let error):
    ///     // .. error handling
    /// }
    @discardableResult
    public func then(on context: ExecutionContext = .main, _ completion: @escaping (FutureResult<Value>) -> Void) -> Future<Value> {
        let observable = Observable<Value>(context: context, observer: completion)
        if let value = self.value {
            self.complete(with: value, observer: observable)
        } else {
            observationQueue.async {
                self.observers.append(observable)
            }
        }
        return self
    }

    /// Calls the completion closure in case of a succesful Future completion
    ///
    /// - parameter on: The ExecutionContext on which the completion closure should be called, defaults to .main
    /// - parameter completion: The closure which will receive the resulting value once the Future is materialized
    ///                         to a successful value, otherwise in case of an error Result it will not be called
    /// - returns: A new chainable Future instance
    @discardableResult
    public func success(on context: ExecutionContext = .main, _ completion: @escaping (Value) -> Void) -> Future<Value> {
        return Future { resolve in
            self.then(on: context) { result in
                switch result {
                case .success(let value):
                    completion(value)
                    resolve(.success(value))
                case .failure(let error):
                    resolve(.failure(error))
                }
            }
        }
    }

    /// Calls the completion closure in case of a failure Future completion
    ///
    /// - parameter on: The ExecutionContext on which the completion closure should be called, defaults to .main
    /// - parameter completion: The closure which will receive the resulting error if the Future materializes 
    ///                         to an error, will not be called otherwise
    /// - returns: A new chainable Future instance
    @discardableResult
    public func failure(on context: ExecutionContext = .main, _ completion: @escaping (Error) -> Void) -> Future<Value> {
        return Future { resolve in
            self.then(on: context) { result in
                switch result {
                case .success(let value):
                    resolve(.success(value))
                case .failure(let error):
                    completion(error)
                    resolve(.failure(error))
                }
            }
        }
    }

    /// Maps the materialized value to type `U`
    /// - parameter on: The ExecutionContext on which the completion closure should be called, defaults to .main
    /// - parameter transform: The transform closure that should map the successful value
    /// - returns: A new chainable Future instance
    ///
    /// ```swift
    /// someFuture.map({ (age: Int) -> String
    ///     return "Age: \(age)
    /// }).success { print($0) }
    @discardableResult
    public func map<U>(on context: ExecutionContext = .main, _ transform: @escaping (Value) -> U) -> Future<U> {
        return Future<U> { resolve in
            self.then(on: context) { result in
                switch result {
                case .success(let value):
                    resolve(.success(transform(value)))
                case .failure(let error):
                    resolve(.failure(error))
                }
            }
        }
    }

    private func complete(with value: FutureResult<Value>) {
        self.value = value
        observationQueue.async {
            var observers = Array(self.observers.reversed())
            self.observers.removeAll()
            while let observer = observers.popLast() {
                self.complete(with: value, observer: observer)
            }
        }
    }

    private func complete(with value: FutureResult<Value>, observer: Observable<Value>) {
        observer.call(value: value)
    }
}
