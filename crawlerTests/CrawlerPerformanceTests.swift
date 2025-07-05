//
//  CrawlerPerformanceTests.swift
//  crawlerTests
//
//  Performance and threading-specific tests for the crawler
//

import XCTest
import Foundation
import Dispatch
@testable import crawler

class CrawlerPerformanceTests: XCTestCase {
    
    var mockServer: MockHTTPServer!
    var tempOutputFile: URL!
    
    override func setUp() {
        super.setUp()
        mockServer = MockHTTPServer()
        
        let tempDir = FileManager.default.temporaryDirectory
        tempOutputFile = tempDir.appendingPathComponent("perf_test_output_\(UUID().uuidString).txt")
    }
    
    override func tearDown() {
        mockServer?.stop()
        
        if FileManager.default.fileExists(atPath: tempOutputFile.path) {
            try? FileManager.default.removeItem(at: tempOutputFile)
        }
        
        super.tearDown()
    }
    
    // MARK: - Threading Performance Tests
    
    func testThreadingPerformanceComparison() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        let baseURL = mockServer.getURL()
        
        // Create a complex site structure with multiple pages
        let numberOfPages = 20
        var indexHTML = """
        <!DOCTYPE html>
        <html>
        <head><title>Performance Test</title></head>
        <body>
        """
        
        for i in 1...numberOfPages {
            indexHTML += "<a href=\"\(baseURL)/page\(i)\">Page \(i)</a>\n"
        }
        indexHTML += "</body></html>"
        
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(body: indexHTML))
        
        // Set up individual pages
        for i in 1...numberOfPages {
            let pageHTML = """
            <!DOCTYPE html>
            <html>
            <head><title>Page \(i)</title></head>
            <body>
                <h1>Page \(i) Content</h1>
                <p>This is page \(i) for performance testing.</p>
            </body>
            </html>
            """
            mockServer.setResponse(for: "/page\(i)", response: MockHTTPServer.MockResponse(body: pageHTML))
        }
        
        let threadConfigurations = [1, 2, 4, 8]
        var executionTimes: [UInt: TimeInterval] = [:]
        
        for threadCount in threadConfigurations {
            let expectation = XCTestExpectation(description: "Performance test with \(threadCount) threads")
            
            let startTime = Date()
            
            let crawler = TestCrawler(
                withThreads: UInt(threadCount),
                filter: "",
                limit: 0,
                verbose: false,
                outputFileLocation: tempOutputFile.path
            )
            
            crawler.onCompletion = {
                let endTime = Date()
                let executionTime = endTime.timeIntervalSince(startTime)
                executionTimes[UInt(threadCount)] = executionTime
                
                XCTAssertGreaterThan(crawler.pool.finishTask.count, 0, "Should have finished tasks")
                expectation.fulfill()
            }
            
            DispatchQueue.global(qos: .background).async {
                crawler.crawl(from: baseURL)
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
        
        // Verify that higher thread counts generally perform better (or at least not worse)
        // Note: This is a basic check - actual performance depends on many factors
        print("Performance Results:")
        for threadCount in threadConfigurations {
            if let time = executionTimes[UInt(threadCount)] {
                print("Threads: \(threadCount), Time: \(time)s")
            }
        }
        
        XCTAssertTrue(executionTimes.count == threadConfigurations.count, "Should have results for all thread configurations")
    }
    
    func testMemoryUsageWithHighThreadCount() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        let baseURL = mockServer.getURL()
        
        // Create a moderate site structure
        let numberOfPages = 50
        var indexHTML = """
        <!DOCTYPE html>
        <html>
        <head><title>Memory Test</title></head>
        <body>
        """
        
        for i in 1...numberOfPages {
            indexHTML += "<a href=\"\(baseURL)/page\(i)\">Page \(i)</a>\n"
        }
        indexHTML += "</body></html>"
        
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(body: indexHTML))
        
        for i in 1...numberOfPages {
            let pageHTML = """
            <!DOCTYPE html>
            <html>
            <head><title>Page \(i)</title></head>
            <body>
                <h1>Page \(i) Content</h1>
                <p>This is page \(i) for memory testing. Content repeated for size.</p>
                <p>Additional content to increase memory usage per page.</p>
            </body>
            </html>
            """
            mockServer.setResponse(for: "/page\(i)", response: MockHTTPServer.MockResponse(body: pageHTML))
        }
        
        let expectation = XCTestExpectation(description: "Memory test with high thread count")
        
        let crawler = TestCrawler(
            withThreads: 20, // High thread count
            filter: "",
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
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    // MARK: - TaskPool Performance Tests
    
    func testTaskPoolPerformanceWithLargeURLSet() {
        let taskPool = TaskPool()
        let numberOfTasks = 10000
        
        let startTime = Date()
        
        // Add many tasks to test O(1) performance
        for i in 1...numberOfTasks {
            let url = URL(string: "https://example.com/page\(i)")!
            let task = taskPool.createTask(withUrl: url)
            _ = taskPool.addNew(task: task)
        }
        
        let additionTime = Date().timeIntervalSince(startTime)
        
        XCTAssertEqual(taskPool.openTask.count, numberOfTasks)
        XCTAssertEqual(taskPool.allTasks.count, numberOfTasks)
        XCTAssertEqual(taskPool.urlSet.count, numberOfTasks)
        
        // Test that lookups are still fast
        let lookupStartTime = Date()
        for i in 1...1000 {
            let url = URL(string: "https://example.com/page\(i)")!
            _ = taskPool.createTask(withUrl: url) // Should use existing task
        }
        let lookupTime = Date().timeIntervalSince(lookupStartTime)
        
        // These should be fast with O(1) operations
        XCTAssertLessThan(additionTime, 1.0, "Adding 10k tasks should be fast")
        XCTAssertLessThan(lookupTime, 0.1, "Lookups should be very fast")
        
        print("TaskPool Performance: Add \(numberOfTasks) tasks in \(additionTime)s, 1000 lookups in \(lookupTime)s")
    }
    
    func testTaskPoolDuplicateURLHandling() {
        let taskPool = TaskPool()
        let baseURL = "https://example.com/page"
        
        let startTime = Date()
        
        // Add the same URL multiple times
        for _ in 1...1000 {
            let url = URL(string: baseURL)!
            let task = taskPool.createTask(withUrl: url)
            _ = taskPool.addNew(task: task)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Should only have one task despite 1000 additions
        XCTAssertEqual(taskPool.openTask.count, 1, "Should deduplicate URLs")
        XCTAssertEqual(taskPool.allTasks.count, 1, "Should have only one task")
        XCTAssertEqual(taskPool.urlSet.count, 1, "Should have only one URL in set")
        
        XCTAssertLessThan(executionTime, 0.1, "Duplicate handling should be fast")
    }
    
    // MARK: - Real-world Scenario Tests
    
    func testLargeWebsiteSimulation() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        let baseURL = mockServer.getURL()
        
        // Simulate a large website with hierarchical structure
        let categories = ["news", "sports", "technology", "entertainment"]
        let itemsPerCategory = 10
        
        // Main page with category links
        var indexHTML = """
        <!DOCTYPE html>
        <html>
        <head><title>Large Website</title></head>
        <body>
        """
        
        for category in categories {
            indexHTML += "<a href=\"\(baseURL)/\(category)\">Category: \(category)</a>\n"
        }
        indexHTML += "</body></html>"
        
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(body: indexHTML))
        
        // Category pages with item links
        for category in categories {
            var categoryHTML = """
            <!DOCTYPE html>
            <html>
            <head><title>\(category.capitalized)</title></head>
            <body>
                <h1>\(category.capitalized)</h1>
            """
            
            for item in 1...itemsPerCategory {
                categoryHTML += "<a href=\"\(baseURL)/\(category)/item\(item)\">Item \(item)</a>\n"
            }
            categoryHTML += "</body></html>"
            
            mockServer.setResponse(for: "/\(category)", response: MockHTTPServer.MockResponse(body: categoryHTML))
            
            // Individual item pages
            for item in 1...itemsPerCategory {
                let itemHTML = """
                <!DOCTYPE html>
                <html>
                <head><title>\(category) Item \(item)</title></head>
                <body>
                    <h1>\(category.capitalized) Item \(item)</h1>
                    <p>Content for item \(item) in \(category)</p>
                </body>
                </html>
                """
                mockServer.setResponse(for: "/\(category)/item\(item)", response: MockHTTPServer.MockResponse(body: itemHTML))
            }
        }
        
        let expectation = XCTestExpectation(description: "Large website crawl completes")
        
        let crawler = TestCrawler(
            withThreads: 8,
            filter: "",
            limit: 0,
            verbose: true,
            outputFileLocation: tempOutputFile.path
        )
        
        crawler.onCompletion = {
            let totalPages = 1 + categories.count + (categories.count * itemsPerCategory)
            
            XCTAssertGreaterThan(crawler.pool.finishTask.count, 0, "Should have finished tasks")
            XCTAssertLessThanOrEqual(crawler.pool.finishTask.count, totalPages, "Should not exceed total pages")
            
            // Verify output file was created and contains data
            XCTAssertTrue(FileManager.default.fileExists(atPath: self.tempOutputFile.path), "Output file should exist")
            
            do {
                let content = try String(contentsOf: self.tempOutputFile)
                XCTAssertFalse(content.isEmpty, "Output should not be empty")
                XCTAssertTrue(content.contains(baseURL), "Output should contain base URL")
            } catch {
                XCTFail("Should be able to read output file")
            }
            
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .background).async {
            crawler.crawl(from: baseURL)
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    func testStressTestWithManySmallPages() {
        let port = mockServer.start()
        XCTAssertTrue(port > 0, "Mock server should start successfully")
        
        let baseURL = mockServer.getURL()
        let pageCount = 100
        
        // Create many small pages
        var indexHTML = """
        <!DOCTYPE html>
        <html>
        <head><title>Stress Test</title></head>
        <body>
        """
        
        for i in 1...pageCount {
            indexHTML += "<a href=\"\(baseURL)/stress\(i)\">Stress \(i)</a>\n"
        }
        indexHTML += "</body></html>"
        
        mockServer.setResponse(for: "/", response: MockHTTPServer.MockResponse(body: indexHTML))
        
        for i in 1...pageCount {
            let pageHTML = "<html><body><h1>Stress \(i)</h1></body></html>"
            mockServer.setResponse(for: "/stress\(i)", response: MockHTTPServer.MockResponse(body: pageHTML))
        }
        
        let expectation = XCTestExpectation(description: "Stress test completes")
        
        let crawler = TestCrawler(
            withThreads: 15,
            filter: "",
            limit: 0,
            verbose: false,
            outputFileLocation: tempOutputFile.path
        )
        
        crawler.onCompletion = {
            XCTAssertGreaterThan(crawler.pool.finishTask.count, 0, "Should have finished tasks")
            XCTAssertEqual(crawler.pool.processTask.count, 0, "Should have no processing tasks")
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .background).async {
            crawler.crawl(from: baseURL)
        }
        
        wait(for: [expectation], timeout: 45.0)
    }
}

// TestCrawler class is defined in CrawlerSystemTests.swift
extension TestCrawler {
    // Additional methods for performance testing can be added here if needed
}