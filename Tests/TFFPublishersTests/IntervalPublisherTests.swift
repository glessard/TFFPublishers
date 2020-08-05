import XCTest
import Combine
import Dispatch

import TFFPublishers

final class IntervalPublisherTests: XCTestCase
{
#if swift(>=5.3)
  func testIntervalPublisher()
  {
    let count = 10
    let delay = 10
    let p = IntervalPublisher(publisher: PartialRangeFrom(0).publisher,
                              interval: .milliseconds(delay)).prefix(count+1)

    let e = expectation(description: #function)
    let start = Date()
    let c = p.sink(receiveCompletion: { _ in e.fulfill()}, receiveValue: { _ in })

    waitForExpectations(timeout: Double(count*delay)*0.1)
    c.cancel()
    let elapsed = Date().timeIntervalSince(start)
    XCTAssertGreaterThan(elapsed, Double(count*delay)*0.001)
  }

  func testIntervalPublisherWithInitialInterval()
  {
    let delay = 10
    let p = IntervalPublisher(publisher: Range(1...2).publisher,
                              scheduler: DispatchQueue(label: #function),
                              initialValue: 0,
                              interval: { .milliseconds(($1 - ($0 ?? 0))*delay) },
                              initialInterval: { .milliseconds($0.map({ ($0+1)*delay }) ?? 0) })

    let e = expectation(description: #function)
    let start = Date()
    let c = p.sink(receiveCompletion: { _ in e.fulfill() }, receiveValue: { _ in })

    waitForExpectations(timeout: 10.0)
    c.cancel()
    let elapsed = Date().timeIntervalSince(start)
    XCTAssertGreaterThan(elapsed, Double(2*delay)*0.001)
  }

  func testIntervalPublisherWithMultipleClosureSyntax()
  {
    var p = IntervalPublisher(publisher: repeatElement(0, count: 10).publisher) { .milliseconds($0 == $1 ? 0 : 1) }
              initialInterval: { _ in .milliseconds(10) }

    p = IntervalPublisher(publisher: repeatElement(0, count: 10).publisher,
                          interval: { .milliseconds($0 == $1 ? 0 : 1) }) { _ in .milliseconds(10) }

#warning("Remove the following compilation condition after Swift 5.3 \"beta 5\"")
#if swift(>=5.3.1)
    p = IntervalPublisher(publisher: repeatElement(0, count: 10).publisher) { .milliseconds($0 == $1 ? 0 : 1) }
#endif

    let e = expectation(description: #function)
    let c = p.sink { _ in e.fulfill() } receiveValue: { _ in }

    waitForExpectations(timeout: 0.1)
    c.cancel()
  }

  func testIntervalPublisherWithFixedInterval()
  {
    let count = 10
    let delay = 10
    let p = IntervalPublisher(publisher: Range(0...count).publisher,
                              scheduler: DispatchQueue(label: #function),
                              interval: .milliseconds(delay))

    let e = expectation(description: #function)
    let start = Date()
    let c = p.sink(receiveCompletion: { _ in e.fulfill() }, receiveValue: { _ in })

    waitForExpectations(timeout: Double(count*delay)*0.1)
    c.cancel()
    let elapsed = Date().timeIntervalSince(start)
    XCTAssertGreaterThan(elapsed, Double(count*delay)*0.001)
  }
#endif
}
