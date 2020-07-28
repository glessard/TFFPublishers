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
}
