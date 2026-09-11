//
//  SmokeTests.swift
//  crawlerTests
//

import XCTest

final class SmokeTests: XCTestCase {

    func testTargetCompilesLinksAndRuns() {
        XCTAssertTrue(true)
    }

    func testCrawlerModuleIsVisible() {
        let task = CrawlerTask(url: URL(string: "https://example.com/")!)
        XCTAssertEqual(task.url.absoluteString, "https://example.com/")
    }
}
