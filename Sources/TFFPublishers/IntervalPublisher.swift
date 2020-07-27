//  IntervalPublisher.swift
//  
//  Copyright © 2020 Guillaume Lessard. All rights reserved

import Combine

public struct IntervalPublisher<P: Publisher, SchedulerType: Scheduler>: Publisher
{
  public typealias Output =  P.Output
  public typealias Failure = P.Failure
  public typealias Interval = SchedulerType.SchedulerTimeType
  public typealias Comparator = (Output?, Output) -> Interval

  private var publisher: Publishers.ReceiveOn<P, SchedulerType>
  private var scheduler: SchedulerType
  private var interval: Comparator

  public init(publisher: P, scheduler: SchedulerType, interval: @escaping (_ previous: Output?, _ current: Output) -> Interval)
  {
    self.publisher = publisher.receive(on: scheduler)
    self.scheduler = scheduler
    self.interval = interval
  }

  public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Downstream.Input == Output, Downstream.Failure == Failure
  {
    let inner = Inner<Downstream, SchedulerType>(downstream: subscriber, scheduler: scheduler, interval: interval)
    subscriber.receive(subscription: inner)
    publisher.subscribe(inner)
  }
}

public struct ConstantIntervalPublisher<P: Publisher, SchedulerType: Scheduler>: Publisher
{
  public typealias Output =  P.Output
  public typealias Failure = P.Failure
  public typealias Interval = SchedulerType.SchedulerTimeType

  private var publisher: IntervalPublisher<P, SchedulerType>

  public init(publisher: P, scheduler: SchedulerType, interval: Interval)
  {
    self.publisher = IntervalPublisher(publisher: publisher, scheduler: scheduler, interval: { _, _ in interval })
  }

  public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Downstream.Input == Output, Downstream.Failure == Failure
  {
    publisher.receive(subscriber: subscriber)
  }
}

extension IntervalPublisher where Output: Equatable
{
  public init(publisher: P, scheduler: SchedulerType, interval: @escaping (_ areEqual: Bool) -> Interval)
  {
    let c: Comparator = { interval($0 == $1) }
    self.init(publisher: publisher, scheduler: scheduler, interval: c)
  }
}

extension IntervalPublisher
{
  fileprivate final class Inner<Downstream: Subscriber, SchedulerType: Scheduler>: Subscriber, Subscription
  {
    typealias Input =   Downstream.Input
    typealias Failure = Downstream.Failure
    typealias Interval = SchedulerType.SchedulerTimeType
    typealias Comparator = (Input?, Input) -> Interval

    private let interval: Comparator
    private let scheduler: SchedulerType

    private let downstream: Downstream
    private var subscription: Subscription?

    private let lock = Lock.allocate()
    private var demand = Subscribers.Demand.none
    private var previous: Input? = nil

    fileprivate init(downstream: Downstream, scheduler: SchedulerType, interval: @escaping Comparator)
    {
      self.downstream = downstream
      self.scheduler = scheduler
      self.interval = interval
    }

    deinit {
      subscription?.cancel()
      lock.deallocate()
    }

    // MARK: Subscription stuff

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

    // MARK: Subscriber stuff

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

    func receive(_ input: Input) -> Subscribers.Demand
    {
      let additional = downstream.receive(input)
      lock.lock()
      demand += additional
      if demand > 0 { demand -= 1 }
      let upstream = (demand > 0) ? subscription : nil
      let prev = previous
      previous = input
      lock.unlock()
      if let upstream = upstream
      {
        let delay = interval(prev, input)
        scheduler.schedule(after: delay, { upstream.request(.max(1)) })
      }
      return .none
    }

    func receive(completion: Subscribers.Completion<Downstream.Failure>)
    {
      lock.lock()
      subscription = nil
      demand = .none
      lock.unlock()
      downstream.receive(completion: completion)
    }
  }
}
