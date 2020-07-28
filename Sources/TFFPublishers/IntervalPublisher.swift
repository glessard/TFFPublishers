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
  public typealias Initial = (Output?) -> Interval

  private var publisher: P
  private var scheduler: SchedulerType
  private var interval: Comparator
  private var initialValue: Output?
  private var initialInterval: Initial

  public init(publisher: P, scheduler: SchedulerType, initialValue: Output? = nil,
              interval: @escaping (_ previous: Output?, _ current: Output) -> Interval,
              initialInterval: @escaping (_ initialValue: Output?) -> Interval = { _ in .seconds(0.0) })
  {
    self.publisher = publisher
    self.scheduler = scheduler
    self.interval = interval
    self.initialValue = initialValue
    self.initialInterval = initialInterval
  }

  public init(publisher: P, scheduler: SchedulerType, initialValue: Output? = nil, interval: Interval)
  {
    self.init(publisher: publisher, scheduler: scheduler, initialValue: initialValue, interval: { _, _ in interval })
  }

  public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Downstream.Input == Output, Downstream.Failure == Failure
  {
    let inner = Inner<Downstream, SchedulerType>(downstream: subscriber,
                                                 scheduler: scheduler,
                                                 initialValue: initialValue,
                                                 interval: interval,
                                                 initialInterval: initialInterval)
    subscriber.receive(subscription: inner)
    publisher.receive(on: scheduler).subscribe(inner)
  }
}

extension IntervalPublisher
  where SchedulerType == DispatchQueue
{
  public init(publisher: P, qos: DispatchQoS = .current, initialValue: Output? = nil,
              interval: @escaping (_ previous: Output?, _ current: Output) -> Interval,
              initialInterval: @escaping (_ initialValue: Output?) -> Interval = { _ in .seconds(0.0) })
  {
    let queue = DispatchQueue(label: #function, qos: qos)
    self.init(publisher: publisher, scheduler: queue, initialValue: initialValue,
              interval: interval, initialInterval: initialInterval)
  }

  public init(publisher: P, qos: DispatchQoS = .current, initialValue: Output? = nil, interval: Interval)
  {
    self.init(publisher: publisher, qos: qos, initialValue: initialValue, interval: { _, _ in interval })
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
    typealias Initial = (Input?) -> Interval

    private let scheduler: SchedulerType
    private let interval: Comparator
    private let initialInterval: Initial

    private let downstream: Downstream
    private var subscription: Subscription?

    private var demand = Subscribers.Demand.none
    private var previous: Input?
    private var streaming = true

    fileprivate init(downstream: Downstream, scheduler: SchedulerType, initialValue: Input?,
                     interval: @escaping Comparator, initialInterval: @escaping Initial)
    {
      self.downstream = downstream
      self.scheduler = scheduler
      self.previous = initialValue
      self.interval = interval
      self.initialInterval = initialInterval
    }

    deinit {
      subscription?.cancel()
    }

    // MARK: Subscription stuff

    func request(_ additional: Subscribers.Demand)
    {
      precondition(additional > 0)
      scheduler.schedule {
        [self] in
        demand += additional
        if !streaming
        {
          let requested = request(after: initialInterval(previous))
          if !requested { subscription?.request(.max(1)) }
        }
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

    // MARK: asynchronous requests

    private func request(after interval: Interval) -> Bool
    {
      guard interval > .seconds(0.0) else { return false }

      let onset = scheduler.now.advanced(by: interval)
      scheduler.schedule(after: onset, { [weak self] in self?.subscription?.request(.max(1)) })
      return true
    }

    // MARK: Subscriber stuff

    func receive(subscription new: Subscription)
    {
      assert(subscription == nil)
      subscription = new
      streaming = (demand > 0)
      if streaming
      {
        let requested = request(after: initialInterval(previous))
        if !requested { subscription?.request(.max(1)) }
      }
    }

    func receive(_ input: Input) -> Subscribers.Demand
    {
      assert(demand > 0)
      demand += downstream.receive(input)
      demand -= 1
      let prev = previous
      previous = input

      streaming = (demand > 0)
      if streaming
      {
        let requested = request(after: interval(prev, input))
        if !requested { return .max(1) }
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
