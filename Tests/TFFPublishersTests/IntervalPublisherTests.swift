import XCTest
import Combine
import Dispatch

import TFFPublishers

final class IntervalPublisherTests: XCTestCase
{
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
    let p = IntervalPublisher(publisher: Range(1...2).publisher,
                              scheduler: DispatchQueue(label: #function),
                              initialValue: 0,
                              interval: { .milliseconds($1 - ($0 ?? 0)) },
                              initialInterval: { .milliseconds($0.map({ $0+1 }) ?? 0) })

    let e = expectation(description: #function)
    let start = Date()
    let c = p.sink(receiveCompletion: { _ in e.fulfill() }, receiveValue: { _ in })

    waitForExpectations(timeout: 10.0)
    c.cancel()
    let elapsed = Date().timeIntervalSince(start)
    XCTAssertGreaterThan(elapsed, 0.002)
  }

  func testIntervalPublisherWithMultipleClosures()
  {
    #if swift(>=5.3)
    let p = IntervalPublisher(publisher: repeatElement(0, count: 10).publisher) { .milliseconds($0 == $1 ? 0 : 1) }
              initialInterval: { _ in .milliseconds(10) }

    let e = expectation(description: #function)
    let c = p.sink { _ in e.fulfill() } receiveValue: { _ in }

    waitForExpectations(timeout: 0.1)
    c.cancel()
    #endif
  }

  func testIntervalPublisherWithFixedInterval()
  {
    let p = IntervalPublisher(publisher: Range(1...10).publisher,
                              scheduler: DispatchQueue(label: #function),
                              interval: .milliseconds(1))

    let e = expectation(description: #function)
    let start = Date()
    let c = p.sink(receiveCompletion: { _ in e.fulfill() }, receiveValue: { _ in })

    waitForExpectations(timeout: 10.0)
    c.cancel()
    let elapsed = Date().timeIntervalSince(start)
    XCTAssertGreaterThan(elapsed, 0.010)
  }
}
