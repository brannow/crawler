# Crawler Test Suite

This directory contains comprehensive system tests for the crawler application. The tests are designed to validate the entire system functionality including network requests, threading, argument parsing, and output generation.

## Test Coverage

### 1. CrawlerSystemTests.swift
**System-level integration tests covering:**
- Command-line argument parsing with all options (-t, -v, -filter, -limit, -o)
- Thread count configuration and validation
- Concurrent task processing with different thread counts
- Filter functionality (blacklisting URLs)
- Limit functionality (maximum URL processing)
- Output file generation and content validation
- Error handling for invalid URLs and HTTP errors
- End-to-end crawling with mock HTTP responses

### 2. CrawlerPerformanceTests.swift
**Performance and threading-specific tests:**
- Threading performance comparison (1, 2, 4, 8 threads)
- Memory usage testing with high thread counts
- TaskPool performance with large URL sets (10,000+ URLs)
- Duplicate URL handling performance
- Large website simulation with hierarchical structure
- Stress testing with many small pages
- Performance benchmarking and timing measurements

### 3. CrawlerEdgeCaseTests.swift
**Edge cases and error conditions:**
- Empty HTML response handling
- Malformed HTML parsing
- Non-HTML response processing
- Relative URL resolution
- Special characters in URLs
- Filter edge cases (empty filters, spaces, single items)
- Limit edge cases (0, 1, unlimited)
- Output file path handling (tilde expansion, non-existent directories)
- Threading edge cases (0 threads, very high thread counts)
- Cache control header processing
- Network timeout and error simulation

### 4. MockHTTPServer.swift
**Test infrastructure:**
- Mock HTTP server for simulating network requests
- Configurable responses with custom status codes and headers
- Support for different content types and response bodies
- Proper cleanup and resource management

## Key Test Features

### 🧵 **Threading Tests**
The test suite specifically validates the `-t` thread argument functionality:
- Tests thread counts from 1 to 20+ threads
- Verifies concurrent processing of multiple URLs
- Measures performance differences between thread configurations
- Ensures thread safety and proper resource management

### 🌐 **Network Simulation**
All tests use a mock HTTP server to simulate real network conditions:
- Configurable HTTP responses with different status codes
- Custom headers including cache control
- Simulation of various HTML structures and content
- Support for error conditions and edge cases

### 📝 **Argument Validation**
Comprehensive testing of all command-line options:
- `-t <number>`: Thread count (thoroughly tested with different values)
- `-v`: Verbose output
- `-filter <list>`: URL filtering/blacklisting
- `-limit <number>`: Maximum URL processing limit
- `-o <file>`: Output file location

### 📊 **Performance Benchmarking**
Performance tests measure:
- Execution time with different thread counts
- Memory usage under high load
- TaskPool efficiency with large URL sets
- Scalability with complex website structures

## Running the Tests

### Option 1: Using the Test Runner Script
```bash
cd crawlerTests
./run_tests.sh
```

### Option 2: Using Xcode
1. Open `crawler.xcodeproj` in Xcode
2. Select the test target
3. Run tests with Cmd+U or through the Test Navigator

### Option 3: Using xcodebuild directly
```bash
# Build first
xcodebuild -project crawler.xcodeproj -scheme crawler -configuration Debug build

# Run tests
xcodebuild test -project crawler.xcodeproj -scheme crawler -destination 'platform=macOS'
```

## Test Architecture

### TestCrawler Class
A specialized subclass of `Crawler` that allows:
- Completion callbacks for asynchronous testing
- Better control over test execution flow
- Proper integration with XCTest expectations

### Mock Server Infrastructure
The `MockHTTPServer` class provides:
- HTTP/1.1 server implementation using NIO
- Configurable response mapping
- Proper resource cleanup
- Support for various HTTP status codes and headers

## Test Categories

### ✅ **System Integration Tests**
- Full end-to-end crawling scenarios
- Real-world website simulation
- Multi-threaded processing validation

### ⚡ **Performance Tests**
- Threading performance comparisons
- Memory usage under load
- Scalability testing
- Benchmark measurements

### 🔍 **Edge Case Tests**
- Error condition handling
- Malformed input processing
- Resource limit testing
- Boundary condition validation

## Important Notes

### Thread Testing
The test suite pays special attention to the `-t` thread argument:
- Tests validate that the specified number of threads is actually used
- Performance tests measure the impact of different thread counts
- Edge case tests ensure proper handling of unusual thread values (0, 1, very high numbers)

### Network Simulation
All network requests are handled by the mock server:
- No external network dependencies
- Deterministic test results
- Fast test execution
- Controllable error conditions

### Resource Management
Tests properly clean up resources:
- Mock servers are stopped after each test
- Temporary files are removed
- Network connections are properly closed
- Memory leaks are prevented

## Expected Test Results

When running the full test suite, you should expect:
- All system integration tests to pass
- Performance tests to complete within reasonable time limits
- Edge case tests to handle error conditions gracefully
- No memory leaks or resource issues
- Proper thread utilization as specified by the `-t` argument

## Troubleshooting

If tests fail:
1. Check that the project builds successfully first
2. Verify that all dependencies are properly installed
3. Ensure no other processes are using the same ports
4. Check system resources (memory, CPU) if performance tests fail
5. Review test output for specific error messages

## Contributing

When adding new tests:
1. Follow the existing test structure and naming conventions
2. Use the MockHTTPServer for network simulation
3. Include proper cleanup in tearDown methods
4. Add comprehensive documentation for new test cases
5. Ensure tests are deterministic and don't rely on external resources