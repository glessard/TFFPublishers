# TFFPublishers [![Build Status](https://www.travis-ci.org/glessard/TFFPublishers.svg?branch=main)](https://www.travis-ci.org/glessard/TFFPublishers)

Some Publishers for use with Combine

##### `ConcatenateMany`:
Concatenate the outputs of a `Stream` of `Publisher`s.

```
public struct ConcatenateMany<Publishers: Sequence>: Publisher
  where S.Element: Publisher
{
  public typealias Output =  Publishers.Element.Output
  public typealias Failure = Publishers.Element.Failure

  public init(publishers: Publishers)
}
```

`ConcatenateMany` terminates normally (with `Completion.finished`) only after all its inputs have terminated. The inputs proceed in order, with no interleaving.
`ConcatenateMany` terminates with error on the first error encountered.

##### `Repeat`:
Re-subscribes to a `Publisher` whenever it ends normally (with `Completion.finished`)

```
public struct Repeat<Upstream: Publisher>: Publisher
{
  public typealias Output =  Upstream.Output
  public typealias Failure = Upstream.Failure

  public init(publisher: Upstream)
}
```

`Repeat` only terminates with an error or after its `Subscriber` cancels.

##### `IntervalPublisher`:
Waits for a time interval before requesting the next element from its upstream `Publisher`

```
public struct IntervalPublisher<Upstream: Publisher, Context: Scheduler>: Publisher
{
  public typealias Output =  Upstream.Output
  public typealias Failure = Upstream.Failure
  public typealias Interval = Context.SchedulerTimeType.Stride

  public init(publisher: Upstream, scheduler: Context, initialValue: Output? = nil,
              interval: @escaping (_ previous: Output?, _ current: Output) -> Interval,
              initialInterval: @escaping(_ initialValue: Output?) -> Interval = { _ in .seconds(0) })
              
  public init(publisher: Upstream, scheduler: Context, initialValue: Output? = nil, interval: Interval)
}

extension IntervalPublisher where Context == DispatchQueue
{
  public init(publisher: Upstream, qos: DispatchQoS = default, initialValue: Output? = nil,
              interval: @escaping (_ previous: Output?, _ current: Output) -> Interval,
              initialInterval: @escaping(_ initialValue: Output?) -> Interval = { _ in .seconds(0) })

  public init(publisher: Pustream, qos: DispatchQoS = default, initialValue: Output? = nil, interval: Interval)              
}
```

All requests to the upstream `Subscription` and deliveries to the downstream `Subscriber` occur on the same `Scheduler`.
