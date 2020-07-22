import XCTest
import Combine
@testable import TFFPublishers

enum TestError: Error, Equatable
{
  case value(Int)
}

final class TFFPublishersTests: XCTestCase
{
  func testRepeat()
  {
    let count = Int.random(in: 10...100)

    let p = Just(1)
    let r = Repeat(publisher: p)
    let x = r.prefix(count).reduce(0, +)

    let e = expectation(description: #function)
    let c = x.sink(
      receiveCompletion: {
        completion in
        XCTAssertEqual(completion, .finished)
        e.fulfill()
      },
      receiveValue: {
        XCTAssertEqual($0, count)
      }
    )

    waitForExpectations(timeout: 1.0)
    c.cancel()
  }

  func testRepeatWithFailure()
  {
    let i = Int.random(in: 1...1000)
    let p = Result<Int, TestError>.failure(.value(i)).publisher
    let r = Repeat(publisher: p)

    let e = expectation(description: #function)
    let c = r.sink(
      receiveCompletion: {
        c in
        XCTAssertEqual(c, .failure(.value(i)))
        e.fulfill()
      },
      receiveValue: { XCTAssertEqual($0, .min) }
    )

    waitForExpectations(timeout: 1.0)
    c.cancel()
  }

  func testConcatenateMany()
  {
    let i = Int.random(in: 10...100)
    let p = (0..<i).reversed().map(Just.init)
    let concatenated = ConcatenateMany(publishers: p).prefix(10)

    let e = expectation(description: #function)
    let c = concatenated.last().sink(
      receiveCompletion: {
        completion in
        XCTAssertEqual(completion, .finished)
        e.fulfill()
      },
      receiveValue: {
        XCTAssertEqual($0, i-10)
      }
    )

    waitForExpectations(timeout: 1.0)
    c.cancel()
  }

  func testConcatenateWithFailures()
  {
    let i = Int.random(in: 1...100)
    let p = (0...i).map {
      j -> Result<Int, TestError>.Publisher in
      let r: Result<Int, TestError>
      if j < i
      { r  = .success(j) }
      else
      { r = .failure(.value(j)) }
      return r.publisher
    }
    let concatenated = ConcatenateMany(publishers: p)

    let e = expectation(description: #function)
    let c = concatenated.sink(
      receiveCompletion: {
        completion in
        XCTAssertEqual(completion, .failure(.value(i)))
        e.fulfill()
      },
      receiveValue: {
        value in
        XCTAssertLessThan(value, i)
      }
    )

    waitForExpectations(timeout: 1.0)
    c.cancel()
  }
}
