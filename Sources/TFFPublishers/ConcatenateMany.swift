import Combine

public struct ConcatenateMany<S: Sequence>: Publisher
  where S.Element: Publisher
{
  public typealias Output =  S.Element.Output
  public typealias Failure = S.Element.Failure

  private let publishers: S

  public init(publishers: S)
  {
    self.publishers = publishers
  }

  public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Downstream.Input == Output, Downstream.Failure == Failure
  {
    let inner = Inner(downstream: subscriber, publishers: publishers)
    subscriber.receive(subscription: inner)
    inner.initiate()
  }
}

extension ConcatenateMany
{
  fileprivate final class Inner<Downstream: Subscriber, S: Sequence>: Subscriber, Subscription
    where S.Element: Publisher, S.Element.Output == Downstream.Input, S.Element.Failure == Downstream.Failure
  {
    typealias Input = Downstream.Input
    typealias Failure = Downstream.Failure

    private var publishers: S.Iterator
    private var current: S.Element?

    private var subscription: Subscription?
    private let downstream: Downstream

    private let lock = Lock()
    private var demand = Subscribers.Demand.none

    fileprivate init(downstream: Downstream, publishers: S)
    {
      self.publishers = publishers.makeIterator()
      self.downstream = downstream
    }

    deinit {
      lock.clean()
    }

    fileprivate func initiate()
    {
      current = publishers.next()
      if let current = current
      {
        current.subscribe(self)
      }
      else
      {
        downstream.receive(completion: .finished)
      }
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
      if demand != .none
      {
        subscription.request(demand)
      }
    }

    func receive(_ input: Downstream.Input) -> Subscribers.Demand
    {
      let additional = downstream.receive(input)
      lock.lock()
      demand -= 1
      demand += additional
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
