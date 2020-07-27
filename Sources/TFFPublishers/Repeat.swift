//  Repeat.swift
//
//  Copyright © 2020 Guillaume Lessard. All rights reserved

import Combine

public struct Repeat<P: Publisher>: Publisher
{
  public typealias Output =  P.Output
  public typealias Failure = P.Failure

  private let source: P

  public init(publisher: P)
  {
    self.source = publisher
  }

  public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Downstream.Input == Output, Downstream.Failure == Failure
  {
    let inner = Inner(downstream: subscriber, publisher: source)
    subscriber.receive(subscription: inner)
    inner.initiate()
  }
}

extension Repeat
{
  fileprivate final class Inner<Downstream: Subscriber, P: Publisher>: Subscriber, Subscription
    where P.Output == Downstream.Input, P.Failure == Downstream.Failure
  {
    typealias Input = Downstream.Input
    typealias Failure = Downstream.Failure

    private let source: P

    private var subscription: Subscription?
    private let downstream: Downstream

    private let lock = Lock()
    private var demand = Subscribers.Demand.none

    fileprivate init(downstream: Downstream, publisher: P)
    {
      self.source = publisher
      self.downstream = downstream
    }

    deinit {
      lock.clean()
    }

    fileprivate func initiate()
    {
      source.subscribe(self)
    }

    // Subscription stuff

    func request(_ demand: Subscribers.Demand)
    {
      lock.lock()
      self.demand += demand
      let upstream = subscription
      lock.unlock()
      upstream?.request(demand)
    }

    func cancel()
    {
      lock.lock()
      demand = .none
      let upstream = subscription
      subscription = nil
      lock.unlock()
      upstream?.cancel()
    }

    // Subscriber stuff
    func receive(subscription: Subscription)
    {
      lock.lock()
      assert(self.subscription == nil)
      self.subscription = subscription
      let demand = self.demand
      lock.unlock()
      if demand > 0
      {
        subscription.request(demand)
      }
    }

    func receive(_ input: Downstream.Input) -> Subscribers.Demand
    {
      let additional = downstream.receive(input)
      lock.lock()
      demand += additional
      if demand > 0 { demand -= 1 }
      lock.unlock()
      return additional
    }

    func receive(completion: Subscribers.Completion<Downstream.Failure>)
    {
      if case .failure = completion
      {
        lock.lock()
        subscription = nil
        demand = .none
        lock.unlock()
        downstream.receive(completion: completion)
        return
      }

      // completed normally: keep concatenating
      lock.lock()
      subscription = nil
      lock.unlock()
      initiate()
    }
  }
}
