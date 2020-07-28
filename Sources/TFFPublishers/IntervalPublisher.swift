//  IntervalPublisher.swift
//  
//  Copyright © 2020 Guillaume Lessard. All rights reserved

import Combine
import Dispatch

import CurrentQoS

public struct IntervalPublisher<P: Publisher, SchedulerType: Scheduler>: Publisher
{
  public typealias Output =  P.Output
  public typealias Failure = P.Failure
  public typealias Interval = SchedulerType.SchedulerTimeType.Stride
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

  public init(publisher: P, scheduler: SchedulerType, interval: @escaping (_ areEqual: Bool) -> Interval)
    where Output: Equatable
  {
    let c: Comparator = { interval($0 == $1) }
    self.init(publisher: publisher, scheduler: scheduler, interval: c)
  }

  public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Downstream.Input == Output, Downstream.Failure == Failure
  {
    let inner = Inner<Downstream, SchedulerType>(downstream: subscriber, scheduler: scheduler, interval: interval)
    subscriber.receive(subscription: inner)
    publisher.subscribe(inner)
  }
}

extension IntervalPublisher
  where SchedulerType == DispatchQueue
{
  public init(publisher: P, qos: DispatchQoS = .current, interval: @escaping (_ previous: Output?, _ current: Output) -> Interval)
  {
    let queue = DispatchQueue(label: #function, qos: qos)
    self.init(publisher: publisher, scheduler: queue, interval: interval)
  }

  public init(publisher: P, qos: DispatchQoS = .current, interval: @escaping (_ areEqual: Bool) -> Interval)
    where Output: Equatable
  {
    let queue = DispatchQueue(label: #function, qos: qos)
    self.init(publisher: publisher, scheduler: queue, interval: interval)
  }
}

public struct FixedIntervalPublisher<P: Publisher, SchedulerType: Scheduler>: Publisher
{
  public typealias Output =  P.Output
  public typealias Failure = P.Failure
  public typealias Interval = SchedulerType.SchedulerTimeType.Stride

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

extension FixedIntervalPublisher
  where SchedulerType == DispatchQueue
{
  public init(publisher: P, qos: DispatchQoS = .current, interval: Interval)
  {
    let queue = DispatchQueue(label: #function, qos: qos)
    self.init(publisher: publisher, scheduler: queue, interval: interval)
  }
}

extension IntervalPublisher
{
  fileprivate final class Inner<Downstream: Subscriber, SchedulerType: Scheduler>: Subscriber, Subscription
  {
    typealias Input =   Downstream.Input
    typealias Failure = Downstream.Failure
    typealias Interval = SchedulerType.SchedulerTimeType.Stride
    typealias Comparator = (Input?, Input) -> Interval

    private let interval: Comparator
    private let scheduler: SchedulerType

    private let downstream: Downstream
    private var subscription: Subscription?

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
    }

    // MARK: Subscription stuff

    func request(_ additional: Subscribers.Demand)
    {
      scheduler.schedule {
        [self] in
        demand += additional
        subscription?.request(additional)
      }
    }

    func cancel()
    {
      scheduler.schedule {
        [self] in
        demand = .none
        let upstream = subscription
        subscription = nil
        upstream?.cancel()
      }
    }

    // MARK: Subscriber stuff

    func receive(subscription: Subscription)
    {
      assert(self.subscription == nil)
      self.subscription = subscription
      if demand > 0
      {
        subscription.request(.max(1))
      }
    }

    func receive(_ input: Input) -> Subscribers.Demand
    {
      demand += downstream.receive(input)
      let prev = previous
      previous = input

      if demand > 0
      {
        demand -= 1
        if let upstream = subscription, demand >= 0
        {
          let onset = scheduler.now.advanced(by: interval(prev, input))
          scheduler.schedule(after: onset, { upstream.request(.max(1)) })
        }
      }
      return .none
    }

    func receive(completion: Subscribers.Completion<Downstream.Failure>)
    {
      subscription = nil
      demand = .none
      downstream.receive(completion: completion)
    }
  }
}
