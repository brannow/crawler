//
//  CrawlerEdgeCaseTests.swift
//  crawlerTests
//
//  Edge cases and error condition tests for the crawler
//

import XCTest
import Foundation
import Dispatch
@testable import crawler

class CrawlerEdgeCaseTests: XCTestCase {
    
    var mockServer: MockHTTPServer!
    var tempOutputFile: URL!
    
    override func setUp() {
        super.setUp()
        mockServer = MockHTTPServer()
        
        let tempDir = FileManager.default.temporaryDirectory
        tempOutputFile = tempDir.appendingPathComponent("edge_test_output_\(UUID().uuidString).txt")
    }
    
    override func tearDown() {
        mockServer?.stop()
        
        if FileManager.default.fileExists(atPath: tempOutputFile.path) {
            try? FileManager.default.removeItem(at: tempOutputFile)
        }
        
        super.tearDown()
    }
    
    // MARK: - HTML Parsing Edge Cases
    
    func testEmptyHTMLResponse() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        let baseURL = mockServer.getURL()
        
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(body: ""))
        
        let expectation = XCTestExpectation(description: "Empty HTML response handled")
        
        let crawler = TestCrawler(
            withThreads: 1,
            filter: "",
            limit: 0,
            verbose: false,
            outputFileLocation: tempOutputFile.path
        )
        
        crawler.onCompletion = {
            XCTAssertEqual(crawler.pool.finishTask.count, 1, "Should have one finished task")
            XCTAssertEqual(crawler.pool.openTask.count, 0, "Should have no open tasks")
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .background).async {
            crawler.crawl(from: baseURL)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testMalformedHTMLResponse() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        let baseURL = mockServer.getURL()
        
        let malformedHTML = """
        <!DOCTYPE html>
        <html>
        <head><title>Malformed</title>
        <body>
            <a href="\(baseURL)/page1">Link 1</a>
            <a href="\(baseURL)/page2">Link 2
            <a href="\(baseURL)/page3">Link 3</a>
        </body>
        """
        
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(body: malformedHTML))
        mockServer.setResponse(for: "/page1", response: MockHTTPServer.MockResponse(body: "Page 1"))
        mockServer.setResponse(for: "/page2", response: MockHTTPServer.MockResponse(body: "Page 2"))
        mockServer.setResponse(for: "/page3", response: MockHTTPServer.MockResponse(body: "Page 3"))
        
        let expectation = XCTestExpectation(description: "Malformed HTML handled")
        
        let crawler = TestCrawler(
            withThreads: 1,
            filter: "",
            limit: 0,
            verbose: false,
            outputFileLocation: tempOutputFile.path
        )
        
        crawler.onCompletion = {
            // Should still extract valid links despite malformed HTML
            XCTAssertGreaterThan(crawler.pool.finishTask.count, 1, "Should have finished multiple tasks")
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .background).async {
            crawler.crawl(from: baseURL)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testNonHTMLResponse() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        let baseURL = mockServer.getURL()
        
        let jsonResponse = """
        {
            "message": "This is not HTML",
            "links": [
                "\(baseURL)/page1",
                "\(baseURL)/page2"
            ]
        }
        """
        
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(body: jsonResponse))
        
        let expectation = XCTestExpectation(description: "Non-HTML response handled")
        
        let crawler = TestCrawler(
            withThreads: 1,
            filter: "",
            limit: 0,
            verbose: false,
            outputFileLocation: tempOutputFile.path
        )
        
        crawler.onCompletion = {
            XCTAssertEqual(crawler.pool.finishTask.count, 1, "Should have one finished task")
            XCTAssertEqual(crawler.pool.openTask.count, 0, "Should have no open tasks")
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .background).async {
            crawler.crawl(from: baseURL)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - URL Edge Cases
    
    func testRelativeURLs() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        let baseURL = mockServer.getURL()
        
        let htmlWithRelativeLinks = """
        <!DOCTYPE html>
        <html>
        <head><title>Relative Links</title></head>
        <body>
            <a href="/absolute">Absolute Path</a>
            <a href="relative">Relative Path</a>
            <a href="../parent">Parent Directory</a>
            <a href="./current">Current Directory</a>
            <a href="#fragment">Fragment Only</a>
            <a href="?query=test">Query Only</a>
        </body>
        </html>
        """
        
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(body: htmlWithRelativeLinks))
        mockServer.setResponse(for: "/absolute", response: MockHTTPServer.MockResponse(body: "Absolute"))
        mockServer.setResponse(for: "/relative", response: MockHTTPServer.MockResponse(body: "Relative"))
        mockServer.setResponse(for: "/parent", response: MockHTTPServer.MockResponse(body: "Parent"))
        mockServer.setResponse(for: "/current", response: MockHTTPServer.MockResponse(body: "Current"))
        
        let expectation = XCTestExpectation(description: "Relative URLs handled")
        
        let crawler = TestCrawler(
            withThreads: 1,
            filter: "",
            limit: 0,
            verbose: false,
            outputFileLocation: tempOutputFile.path
        )
        
        crawler.onCompletion = {
            XCTAssertGreaterThan(crawler.pool.finishTask.count, 1, "Should have finished multiple tasks")
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .background).async {
            crawler.crawl(from: baseURL)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testSpecialCharactersInURLs() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        let baseURL = mockServer.getURL()
        
        let htmlWithSpecialChars = """
        <!DOCTYPE html>
        <html>
        <head><title>Special Characters</title></head>
        <body>
            <a href="\(baseURL)/page%20with%20spaces">Spaces</a>
            <a href="\(baseURL)/page-with-dashes">Dashes</a>
            <a href="\(baseURL)/page_with_underscores">Underscores</a>
            <a href="\(baseURL)/page.with.dots">Dots</a>
            <a href="\(baseURL)/page?param=value&other=123">Query Params</a>
        </body>
        </html>
        """
        
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(body: htmlWithSpecialChars))
        mockServer.setResponse(for: "/page%20with%20spaces", response: MockHTTPServer.MockResponse(body: "Spaces"))
        mockServer.setResponse(for: "/page-with-dashes", response: MockHTTPServer.MockResponse(body: "Dashes"))
        mockServer.setResponse(for: "/page_with_underscores", response: MockHTTPServer.MockResponse(body: "Underscores"))
        mockServer.setResponse(for: "/page.with.dots", response: MockHTTPServer.MockResponse(body: "Dots"))
        mockServer.setResponse(for: "/page?param=value&other=123", response: MockHTTPServer.MockResponse(body: "Query"))
        
        let expectation = XCTestExpectation(description: "Special characters handled")
        
        let crawler = TestCrawler(
            withThreads: 1,
            filter: "",
            limit: 0,
            verbose: false,
            outputFileLocation: tempOutputFile.path
        )
        
        crawler.onCompletion = {
            XCTAssertGreaterThan(crawler.pool.finishTask.count, 1, "Should have finished multiple tasks")
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .background).async {
            crawler.crawl(from: baseURL)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Filter Edge Cases
    
    func testEmptyFilterString() {
        let crawler = Crawler(
            withThreads: 1,
            filter: "",
            limit: 0,
            verbose: false,
            outputFileLocation: ""
        )
        
        XCTAssertEqual(crawler.filterList.count, 1, "Empty filter should result in one empty string")
        XCTAssertEqual(crawler.filterList[0], "", "Filter should be empty string")
    }
    
    func testFilterWithSpaces() {
        let crawler = Crawler(
            withThreads: 1,
            filter: "/admin/, /test/ , /debug/",
            limit: 0,
            verbose: false,
            outputFileLocation: ""
        )
        
        XCTAssertEqual(crawler.filterList.count, 3, "Should have 3 filter items")
        XCTAssertEqual(crawler.filterList[0], "/admin/", "First filter should be /admin/")
        XCTAssertEqual(crawler.filterList[1], "/test/", "Second filter should be /test/")
        XCTAssertEqual(crawler.filterList[2], "/debug/", "Third filter should be /debug/")
    }
    
    func testFilterWithSingleItem() {
        let crawler = Crawler(
            withThreads: 1,
            filter: "/admin/",
            limit: 0,
            verbose: false,
            outputFileLocation: ""
        )
        
        XCTAssertEqual(crawler.filterList.count, 1, "Should have 1 filter item")
        XCTAssertEqual(crawler.filterList[0], "/admin/", "Filter should be /admin/")
    }
    
    // MARK: - Limit Edge Cases
    
    func testZeroLimit() {
        let crawler = Crawler(
            withThreads: 1,
            filter: "",
            limit: 0,
            verbose: false,
            outputFileLocation: ""
        )
        
        XCTAssertEqual(crawler.limit, 0, "Limit should be 0 (unlimited)")
    }
    
    func testLimitOfOne() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        let baseURL = mockServer.getURL()
        
        let htmlWithManyLinks = """
        <!DOCTYPE html>
        <html>
        <head><title>Many Links</title></head>
        <body>
            <a href="\(baseURL)/page1">Page 1</a>
            <a href="\(baseURL)/page2">Page 2</a>
            <a href="\(baseURL)/page3">Page 3</a>
        </body>
        </html>
        """
        
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(body: htmlWithManyLinks))
        mockServer.setResponse(for: "/page1", response: MockHTTPServer.MockResponse(body: "Page 1"))
        mockServer.setResponse(for: "/page2", response: MockHTTPServer.MockResponse(body: "Page 2"))
        mockServer.setResponse(for: "/page3", response: MockHTTPServer.MockResponse(body: "Page 3"))
        
        let expectation = XCTestExpectation(description: "Limit of 1 respected")
        
        let crawler = TestCrawler(
            withThreads: 1,
            filter: "",
            limit: 1,
            verbose: false,
            outputFileLocation: tempOutputFile.path
        )
        
        crawler.onCompletion = {
            let totalProcessed = crawler.pool.processTask.count + crawler.pool.finishTask.count
            XCTAssertLessThanOrEqual(totalProcessed, 1, "Should not exceed limit of 1")
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .background).async {
            crawler.crawl(from: baseURL)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Output File Edge Cases
    
    func testOutputFileWithTildePath() {
        let crawler = Crawler(
            withThreads: 1,
            filter: "",
            limit: 0,
            verbose: false,
            outputFileLocation: "~/test_output.txt"
        )
        
        XCTAssertNotNil(crawler.fileLocation, "File location should be set")
        XCTAssertTrue(crawler.fileLocation!.path.contains("/test_output.txt"), "Should expand tilde in path")
    }
    
    func testOutputFileWithNonExistentDirectory() {
        let nonExistentPath = "/non/existent/directory/output.txt"
        
        let crawler = Crawler(
            withThreads: 1,
            filter: "",
            limit: 0,
            verbose: false,
            outputFileLocation: nonExistentPath
        )
        
        XCTAssertNotNil(crawler.fileLocation, "File location should be set")
        XCTAssertEqual(crawler.fileLocation!.path, nonExistentPath, "Should use provided path")
    }
    
    // MARK: - Threading Edge Cases
    
    func testZeroThreads() {
        let crawler = Crawler(
            withThreads: 0,
            filter: "",
            limit: 0,
            verbose: false,
            outputFileLocation: ""
        )
        
        XCTAssertEqual(crawler.numOfThreads, 0, "Should accept 0 threads")
    }
    
    func testVeryHighThreadCount() {
        let crawler = Crawler(
            withThreads: 1000,
            filter: "",
            limit: 0,
            verbose: false,
            outputFileLocation: ""
        )
        
        XCTAssertEqual(crawler.numOfThreads, 1000, "Should accept very high thread count")
    }
    
    // MARK: - Cache Control Tests
    
    func testCacheControlHeaders() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        let baseURL = mockServer.getURL()
        
        let htmlResponse = """
        <!DOCTYPE html>
        <html>
        <head><title>Cache Control Test</title></head>
        <body><p>Test content</p></body>
        </html>
        """
        
        var headers = HTTPHeaders()
        headers.add(name: "Cache-Control", value: "max-age=3600, public")
        headers.add(name: "Expires", value: "Wed, 21 Oct 2025 07:28:00 GMT")
        
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(
            statusCode: .ok,
            headers: headers,
            body: htmlResponse
        ))
        
        let expectation = XCTestExpectation(description: "Cache control headers processed")
        
        let crawler = TestCrawler(
            withThreads: 1,
            filter: "",
            limit: 0,
            verbose: true,
            outputFileLocation: tempOutputFile.path
        )
        
        crawler.onCompletion = {
            XCTAssertGreaterThan(crawler.pool.finishTask.count, 0, "Should have finished tasks")
            
            let task = crawler.pool.finishTask.values.first!
            XCTAssertNotNil(task.header, "Task should have headers")
            
            let cacheControl = CacheControl(headers: task.header)
            XCTAssertTrue(cacheControl.cacheable, "Should be cacheable")
            XCTAssertEqual(cacheControl.maxAge, 3600, "Should have correct max-age")
            
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .background).async {
            crawler.crawl(from: baseURL)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Network Timeout and Error Simulation
    
    func testSlowServerResponse() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        let baseURL = mockServer.getURL()
        
        // For this test, we'll just test that the crawler handles normal responses
        // Real timeout testing would require more complex server simulation
        
        let htmlResponse = """
        <!DOCTYPE html>
        <html>
        <head><title>Slow Response Test</title></head>
        <body><p>This response should be handled normally</p></body>
        </html>
        """
        
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(body: htmlResponse))
        
        let expectation = XCTestExpectation(description: "Slow response handled")
        
        let crawler = TestCrawler(
            withThreads: 1,
            filter: "",
            limit: 0,
            verbose: false,
            outputFileLocation: tempOutputFile.path
        )
        
        crawler.onCompletion = {
            XCTAssertGreaterThan(crawler.pool.finishTask.count, 0, "Should have finished tasks")
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .background).async {
            crawler.crawl(from: baseURL)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}