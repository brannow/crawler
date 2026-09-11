//
//  CrawlerSystemTests.swift
//  crawlerTests
//
//  Comprehensive system tests for the crawler application
//

import XCTest
import Foundation
import Dispatch
import NIOHTTP1

class CrawlerSystemTests: XCTestCase {
    
    var mockServer: MockHTTPServer!
    var tempOutputFile: URL!
    
    override func setUp() {
        super.setUp()
        mockServer = MockHTTPServer()
        
        // Create temporary output file
        let tempDir = FileManager.default.temporaryDirectory
        tempOutputFile = tempDir.appendingPathComponent("test_output_\(UUID().uuidString).txt")
    }
    
    override func tearDown() {
        mockServer?.stop()
        
        // Clean up temp file
        if FileManager.default.fileExists(atPath: tempOutputFile.path) {
            try? FileManager.default.removeItem(at: tempOutputFile)
        }
        
        super.tearDown()
    }
    
    // MARK: - Command Line Argument Tests
    
    func testArgumentParsingWithAllOptions() {
        let arguments = [
            "crawler",
            "-t", "5",
            "-v",
            "-filter", "/admin/,/test/",
            "-limit", "100",
            "-o", "/tmp/output.txt",
            "https://example.com/"
        ]
        
        let config = [
            OptionType(withKey: "-t", hasValue: true),
            OptionType(withKey: "-v"),
            OptionType(withKey: "-filter", hasValue: true),
            OptionType(withKey: "-limit", hasValue: true),
            OptionType(withKey: "-o", hasValue: true)
        ]
        
        let result = ArgumentParser.parse(arguments: arguments, config: config)
        
        XCTAssertEqual(result.getOptionValue(key: "-t", defaultValue: "1").value, "5")
        XCTAssertTrue(result.hasOption(key: "-v"))
        XCTAssertEqual(result.getOptionValue(key: "-filter", defaultValue: "").value, "/admin/,/test/")
        XCTAssertEqual(result.getOptionValue(key: "-limit", defaultValue: "0").value, "100")
        XCTAssertEqual(result.getOptionValue(key: "-o", defaultValue: "").value, "/tmp/output.txt")
        XCTAssertEqual(result.arguments.count, 1)
        XCTAssertEqual(result.arguments[0].value, "https://example.com/")
    }
    
    func testArgumentParsingWithDefaults() {
        let arguments = ["crawler", "https://example.com/"]
        let config = [
            OptionType(withKey: "-t", hasValue: true),
            OptionType(withKey: "-v"),
            OptionType(withKey: "-filter", hasValue: true),
            OptionType(withKey: "-limit", hasValue: true),
            OptionType(withKey: "-o", hasValue: true)
        ]
        
        let result = ArgumentParser.parse(arguments: arguments, config: config)
        
        XCTAssertEqual(result.getOptionValue(key: "-t", defaultValue: "1").value, "1")
        XCTAssertFalse(result.hasOption(key: "-v"))
        XCTAssertEqual(result.getOptionValue(key: "-filter", defaultValue: "").value, "")
        XCTAssertEqual(result.getOptionValue(key: "-limit", defaultValue: "0").value, "0")
        XCTAssertEqual(result.getOptionValue(key: "-o", defaultValue: "").value, "")
        XCTAssertEqual(result.arguments.count, 1)
        XCTAssertEqual(result.arguments[0].value, "https://example.com/")
    }
    
    func testArgumentParsingWithInvalidOptions() {
        let arguments = [
            "crawler",
            "-invalid", "value",
            "-t", "5",
            "https://example.com/"
        ]
        
        let config = [
            OptionType(withKey: "-t", hasValue: true),
            OptionType(withKey: "-v")
        ]
        
        let result = ArgumentParser.parse(arguments: arguments, config: config)
        
        XCTAssertEqual(result.getOptionValue(key: "-t", defaultValue: "1").value, "5")
        XCTAssertFalse(result.hasOption(key: "-invalid"))
        XCTAssertEqual(result.arguments.count, 2) // URL and "value" from invalid option
    }
    
    // MARK: - Threading Tests
    
    func testThreadCountConfiguration() {
        let crawler1 = Crawler(
            withThreads: 1,
            filter: "",
            keywords: "",
            limit: 0,
            verbose: false,
            outputFileLocation: ""
        )
        
        let crawler5 = Crawler(
            withThreads: 5,
            filter: "",
            keywords: "",
            limit: 0,
            verbose: false,
            outputFileLocation: ""
        )
        
        let crawler10 = Crawler(
            withThreads: 10,
            filter: "",
            keywords: "",
            limit: 0,
            verbose: false,
            outputFileLocation: ""
        )
        
        XCTAssertEqual(crawler1.numOfThreads, 1)
        XCTAssertEqual(crawler5.numOfThreads, 5)
        XCTAssertEqual(crawler10.numOfThreads, 10)
    }
    
    func testConcurrentTaskProcessing() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        // Set up multiple pages with links
        let baseURL = mockServer.getURL()
        
        let indexHTML = """
        <!DOCTYPE html>
        <html>
        <head><title>Test Page</title></head>
        <body>
            <a href="\(baseURL)/page1">Page 1</a>
            <a href="\(baseURL)/page2">Page 2</a>
            <a href="\(baseURL)/page3">Page 3</a>
        </body>
        </html>
        """
        
        let page1HTML = """
        <!DOCTYPE html>
        <html>
        <head><title>Page 1</title></head>
        <body><h1>Page 1 Content</h1></body>
        </html>
        """
        
        let page2HTML = """
        <!DOCTYPE html>
        <html>
        <head><title>Page 2</title></head>
        <body><h1>Page 2 Content</h1></body>
        </html>
        """
        
        let page3HTML = """
        <!DOCTYPE html>
        <html>
        <head><title>Page 3</title></head>
        <body><h1>Page 3 Content</h1></body>
        </html>
        """
        
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(body: indexHTML))
        mockServer.setResponse(for: "/page1", response: MockHTTPServer.MockResponse(body: page1HTML))
        mockServer.setResponse(for: "/page2", response: MockHTTPServer.MockResponse(body: page2HTML))
        mockServer.setResponse(for: "/page3", response: MockHTTPServer.MockResponse(body: page3HTML))
        
        // Test with different thread counts
        let threadCounts: [UInt] = [1, 3, 5]
        
        for threadCount in threadCounts {
            let expectation = XCTestExpectation(description: "Crawler with \(threadCount) threads completes")
            
            let crawler = TestCrawler(
                withThreads: threadCount,
                filter: "",
                keywords: "",
                limit: 0,
                verbose: false,
                outputFileLocation: tempOutputFile.path
            )
            
            crawler.onCompletion = {
                XCTAssertGreaterThan(crawler.pool.finishTask.count, 0, "Should have finished tasks")
                XCTAssertEqual(crawler.pool.processTask.count, 0, "Should have no processing tasks when complete")
                expectation.fulfill()
            }
            
            DispatchQueue.global(qos: .background).async {
                crawler.crawl(from: baseURL)
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Filter Tests
    
    func testFilterFunctionality() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        let baseURL = mockServer.getURL()
        
        let indexHTML = """
        <!DOCTYPE html>
        <html>
        <head><title>Test Page</title></head>
        <body>
            <a href="\(baseURL)/admin/login">Admin Login</a>
            <a href="\(baseURL)/user/profile">User Profile</a>
            <a href="\(baseURL)/fileadmin/files">File Admin</a>
            <a href="\(baseURL)/public/page">Public Page</a>
        </body>
        </html>
        """
        
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(body: indexHTML))
        mockServer.setResponse(for: "/admin/login", response: MockHTTPServer.MockResponse(body: "Admin"))
        mockServer.setResponse(for: "/user/profile", response: MockHTTPServer.MockResponse(body: "User"))
        mockServer.setResponse(for: "/fileadmin/files", response: MockHTTPServer.MockResponse(body: "Files"))
        mockServer.setResponse(for: "/public/page", response: MockHTTPServer.MockResponse(body: "Public"))
        
        let expectation = XCTestExpectation(description: "Crawler with filter completes")
        
        let crawler = TestCrawler(
            withThreads: 1,
            filter: "/admin/,/fileadmin/",
            keywords: "",
            limit: 0,
            verbose: false,
            outputFileLocation: tempOutputFile.path
        )
        
        crawler.onCompletion = {
            // Should have blacklisted admin and fileadmin URLs
            XCTAssertGreaterThan(crawler.pool.blacklist.count, 0, "Should have blacklisted URLs")
            
            // Check that blacklisted URLs contain the filtered ones
            let blacklistedURLs = crawler.pool.blacklist.values.map { $0.url.absoluteString }
            XCTAssertTrue(blacklistedURLs.contains { $0.contains("/admin/") }, "Should blacklist admin URLs")
            XCTAssertTrue(blacklistedURLs.contains { $0.contains("/fileadmin/") }, "Should blacklist fileadmin URLs")
            
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .background).async {
            crawler.crawl(from: baseURL)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Limit Tests
    
    func testLimitFunctionality() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        let baseURL = mockServer.getURL()
        
        let indexHTML = """
        <!DOCTYPE html>
        <html>
        <head><title>Test Page</title></head>
        <body>
            <a href="\(baseURL)/page1">Page 1</a>
            <a href="\(baseURL)/page2">Page 2</a>
            <a href="\(baseURL)/page3">Page 3</a>
            <a href="\(baseURL)/page4">Page 4</a>
            <a href="\(baseURL)/page5">Page 5</a>
        </body>
        </html>
        """
        
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(body: indexHTML))
        for i in 1...5 {
            mockServer.setResponse(for: "/page\(i)", response: MockHTTPServer.MockResponse(body: "Page \(i)"))
        }
        
        let expectation = XCTestExpectation(description: "Crawler with limit completes")
        
        let crawler = TestCrawler(
            withThreads: 1,
            filter: "",
            keywords: "",
            limit: 3,
            verbose: false,
            outputFileLocation: tempOutputFile.path
        )
        
        crawler.onCompletion = {
            let totalProcessed = crawler.pool.processTask.count + crawler.pool.finishTask.count
            XCTAssertLessThanOrEqual(totalProcessed, 3, "Should not exceed the limit")
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .background).async {
            crawler.crawl(from: baseURL)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Output Generation Tests
    
    func testOutputFileGeneration() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        let baseURL = mockServer.getURL()
        
        let indexHTML = """
        <!DOCTYPE html>
        <html>
        <head><title>Test Page</title></head>
        <body>
            <a href="\(baseURL)/page1">Page 1</a>
            <a href="\(baseURL)/page2">Page 2</a>
        </body>
        </html>
        """
        
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(body: indexHTML))
        mockServer.setResponse(for: "/page1", response: MockHTTPServer.MockResponse(body: "Page 1"))
        mockServer.setResponse(for: "/page2", response: MockHTTPServer.MockResponse(body: "Page 2"))
        
        let expectation = XCTestExpectation(description: "Crawler generates output file")
        
        let crawler = TestCrawler(
            withThreads: 1,
            filter: "",
            keywords: "",
            limit: 0,
            verbose: false,
            outputFileLocation: tempOutputFile.path
        )
        
        crawler.onCompletion = {
            crawler.generateOutput()
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: self.tempOutputFile.path), "Output file should be created")
            
            do {
                let content = try String(contentsOf: self.tempOutputFile, encoding: .utf8)
                XCTAssertFalse(content.isEmpty, "Output file should not be empty")
                
                // Check that the output contains URLs
                XCTAssertTrue(content.contains(baseURL), "Output should contain base URL")
                
            } catch {
                XCTFail("Should be able to read output file: \(error)")
            }
            
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .background).async {
            crawler.crawl(from: baseURL)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidURLHandling() {
        // Exercises Crawler.crawl()'s real validation via exitHandler, rather than
        // duplicating the validation rule inline -- a prior copy of this check
        // drifted out of sync with Crawler.crawl() and silently stopped catching
        // ftp:// and empty-scheme URLs.
        let invalidURLs = [
            "not-a-url",
            "ftp://example.com",
            "://invalid",
            ""
        ]

        for invalidURL in invalidURLs {
            let crawler = Crawler(
                withThreads: 1,
                filter: "",
                keywords: "",
                limit: 0,
                verbose: false,
                outputFileLocation: ""
            )

            var rejectedWithCode: Int32? = nil
            crawler.exitHandler = { code in rejectedWithCode = code }

            crawler.crawl(from: invalidURL)

            XCTAssertEqual(rejectedWithCode, 1, "URL \(invalidURL) should be considered invalid")
        }
    }
    
    func testHTTPErrorHandling() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        let baseURL = mockServer.getURL()
        
        // Set up responses with different HTTP status codes
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(
            statusCode: .ok,
            body: """
            <!DOCTYPE html>
            <html>
            <body>
                <a href="\(baseURL)/notfound">Not Found</a>
                <a href="\(baseURL)/error">Server Error</a>
            </body>
            </html>
            """
        ))
        
        mockServer.setResponse(for: "/notfound", response: MockHTTPServer.MockResponse(
            statusCode: .notFound,
            body: "404 Not Found"
        ))
        
        mockServer.setResponse(for: "/error", response: MockHTTPServer.MockResponse(
            statusCode: .internalServerError,
            body: "500 Internal Server Error"
        ))
        
        let expectation = XCTestExpectation(description: "Crawler handles HTTP errors")
        
        let crawler = TestCrawler(
            withThreads: 1,
            filter: "",
            keywords: "",
            limit: 0,
            verbose: true,
            outputFileLocation: tempOutputFile.path
        )
        
        crawler.onCompletion = {
            // Check that tasks were processed even with errors
            XCTAssertGreaterThan(crawler.pool.finishTask.count, 0, "Should have finished tasks")
            
            // Check that error status codes were recorded
            let tasks = Array(crawler.pool.finishTask.values)
            let statusCodes = tasks.map { $0.code }
            
            XCTAssertTrue(statusCodes.contains(200), "Should have successful responses")
            XCTAssertTrue(statusCodes.contains(404), "Should have 404 responses")
            XCTAssertTrue(statusCodes.contains(500), "Should have 500 responses")
            
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .background).async {
            crawler.crawl(from: baseURL)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}

// Test subclass to allow completion handling
class TestCrawler: Crawler {
    var onCompletion: (() -> Void)?

    override init(withThreads: UInt = 1, filter: String, keywords: String, limit: UInt = 0, verbose: Bool, outputFileLocation: String = "", maxAttempts: UInt = 3) {
        super.init(withThreads: withThreads, filter: filter, keywords: keywords, limit: limit, verbose: verbose, outputFileLocation: outputFileLocation, maxAttempts: maxAttempts)

        // Crawler.exitHandler defaults to a real exit(), which would kill the
        // whole XCTest process instead of just ending this crawl. Route it to
        // the completion callback instead -- this fires at exactly the two
        // points (all tasks done, or limit reached) that used to call exit(0).
        exitHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.onCompletion?()
            }
        }
    }
}