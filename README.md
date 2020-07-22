# TFFPublishers

Some Publishers for use with Combine

##### `ConcatenateMany`:
Concatenate the outputs of a `Stream` of `Publisher`s.

```
public struct ConcatenateMany<S: Sequence>: Publisher
  where S.Element: Publisher
{
  public typealias Output =  S.Element.Output
  public typealias Failure = S.Element.Failure

  public init(publishers: S)
}
```

`ConcatenateMany` terminates normally (with `Completion.finished`) only after all its inputs have terminated. The inputs proceed in order, with no interleaving.
`ConcatenateMany` terminates with error on the first error encountered.

##### `Repeat`:
Restart a `Publisher` whenever it ends normally (with `Completion.finished`)

```
public struct Repeat<P: Publisher>: Publisher
{
  public typealias Output =  P.Output
  public typealias Failure = P.Failure

  public init(publisher: P)
}
```

`Repeat` only terminates with an error or after its `Subscriber` cancels.
