# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Swift-based web crawler command-line tool that crawls websites and extracts URLs. The crawler supports multi-threaded operation, filtering, and output generation.

## Build and Development Commands

### Building the Project
```bash
# Build using Xcode (preferred)
xcodebuild -project crawler.xcodeproj -scheme crawler -configuration Debug build

# Build for release
xcodebuild -project crawler.xcodeproj -scheme crawler -configuration Release build
```

### Running the Crawler
```bash
# Basic usage
./crawler -v -t 10 -filter "/fileadmin/,tx_news,tx_t3events_events" -o ~/Desktop/list.txt https://example.com/

# Command line options:
# -t <number>     : Number of threads (default: 1)
# -v             : Verbose output
# -filter <list> : Comma-separated list of URL patterns to blacklist
# -limit <number>: Maximum number of URLs to process (default: 0 = unlimited)
# -o <file>      : Output file location
```

## Architecture

### Core Components

- **main.swift**: Entry point with command-line argument parsing and signal handling
- **Crawler.swift**: Main crawler class implementing NetworkLoaderDelegate
- **TaskPool.swift**: Manages crawler tasks and their states (open, processing, finished, blacklisted)
- **NetworkLoader.swift**: Handles HTTP requests using SwiftyRequest library
- **HTMLLinkParser.swift**: Parses HTML content to extract URLs using cached regex
- **OutputGenerator.swift**: Generates final output from crawled data with ID tracking
- **CacheControl.swift**: Handles HTTP cache control headers (max-age, cacheable)

### Data Transfer Objects (DTOs)
- **CrawlerTask.swift**: Represents individual crawling tasks with parent-child relationships
- **CommandArgumentParser.swift** & **CommandArgumentResult.swift**: Command-line argument handling

### ID System and Task Tracking

The crawler implements a sophisticated ID system designed for tracking requests and their origins in large page networks:

#### **Unique ID Generation**
- **Sequential IDs**: Each unique URL gets a sequential UInt ID (0, 1, 2, ...)
- **URL Deduplication**: Uses `Set<String>` and `HashMap` for O(1) URL lookup and deduplication
- **ID Persistence**: Same URL always gets the same ID across the entire crawl session

#### **Parent-Child Relationship Tracking**
```swift
class CrawlerTask {
    var parentId: Set<UInt> = []  // Multiple parents possible
    var id: UInt? = nil
    // ... other properties
}
```

- **Multi-Parent Support**: URLs can be discovered from multiple pages
- **Origin Tracking**: Every URL maintains complete trace of discovery sources
- **Blacklist Tracking**: Even filtered URLs maintain parent relationships for analysis

#### **Task State Management**
The TaskPool manages tasks through five distinct collections:
- `openTask: [UInt: CrawlerTask]` - Ready to process
- `processTask: [UInt: CrawlerTask]` - Currently being crawled
- `finishTask: [UInt: CrawlerTask]` - Completed successfully
- `blacklist: [UInt: CrawlerTask]` - Filtered/blacklisted URLs
- `allTasks: [UInt: CrawlerTask]` - Master collection for output generation

### Key Design Patterns

1. **Multi-threaded Architecture**: Uses DispatchQueue for concurrent URL processing
2. **Delegate Pattern**: NetworkLoaderDelegate for handling network responses
3. **Task Pool Management**: Centralized task state management with different queues
4. **Signal Handling**: Graceful shutdown with SIGINT handling to generate output before exit

### Dependencies
- **SwiftyRequest**: HTTP networking library (version 3.2.200+)
- **Foundation**: Core Swift framework
- **Dispatch**: Concurrency framework

### URL Processing Flow
1. Parse command-line arguments
2. Create initial task from starting URL
3. Process tasks concurrently using thread pool
4. Extract URLs from HTML responses
5. Filter URLs against blacklist
6. Add new tasks to pool
7. Generate output file when complete or interrupted

### Output Format

The crawler generates two types of output:

#### **Console Output (Verbose Mode)**
Real-time progress information showing:
- Task counts (o:open|f:finished|b:blacklisted|a:all)
- HTTP response codes
- Cache control information (cacheable, max-age)
- Response times in milliseconds
- URL being processed
- Timestamp for each request

Example console output:
```
[14:32:15] (o:5|f:12|b:3|a:20) 200 true 3600 245ms https://example.com/page1
[14:32:16] (o:4|f:13|b:3|a:20) 404 false -1 123ms https://example.com/missing
```

#### **Output File Format**
The final output file contains a comprehensive report with the following space-separated columns:

```
ID Parent_Ids HTTP_CODE cacheable maxAge Request_Time_MS URL
```

**Column Descriptions:**
- **ID**: Unique sequential identifier for each URL (0, 1, 2, ...)
- **Parent_Ids**: Comma-separated list of parent IDs that discovered this URL
- **HTTP_CODE**: HTTP response status code (200, 404, 500, etc.)
- **cacheable**: Boolean indicating if response is cacheable (true/false)
- **maxAge**: Cache max-age in seconds (-1 if not specified)
- **Request_Time_MS**: Response time in milliseconds
- **URL**: The complete URL that was crawled

**Example Output File:**
```
ID Parent_Ids HTTP_CODE cacheable maxAge Request_Time_MS URL
0  200 true 3600 156.7 https://example.com/
1 0 200 true 1800 89.2 https://example.com/about
2 0 200 false -1 234.5 https://example.com/contact
3 0,1 404 false -1 67.8 https://example.com/missing
4 1 200 true 7200 145.3 https://example.com/team
```

#### **Request Tracing and Network Analysis**
The ID system enables powerful network analysis capabilities:

1. **Origin Tracking**: Trace how any URL was discovered
   - URL with ID 3 was found from pages 0 and 1
   - URL with ID 4 was only found from page 1

2. **Dependency Analysis**: Understand site structure
   - Root page (ID 0) typically has no parent
   - Deep pages show discovery chains

3. **Blacklist Analysis**: Track filtered URLs
   - Blacklisted URLs appear in output with parent relationships
   - Helps identify which pages link to filtered content

4. **Performance Analysis**: Identify slow requests
   - Response times help identify bottlenecks
   - Cache analysis shows optimization opportunities

5. **Error Tracking**: Debug broken links
   - 404 errors with parent IDs show which pages have broken links
   - Multi-parent URLs with errors affect multiple pages

## Performance Optimizations (Applied July 2025)

### Critical Bug Fixes Applied
- **Typo Fixes**: Fixed `ArguemntParser` → `ArgumentParser`, `porcessTask` → `processTask`, `CommandArguemntResult` → `CommandArgumentResult`
- **File Path Bug**: Fixed `absoluteString` → `path` in file operations (Crawler.swift:56)
- **Memory Leak**: Fixed EventLoopGroup per-request creation causing memory leaks

### Threading Architecture (IMPORTANT)
- **User Threading (-t option)**: Controls crawler concurrency - how many pages crawled simultaneously
  - `-t 1` (default): Crawls 1 page at a time
  - `-t 10`: Crawls 10 pages simultaneously
  - Main thread manages TaskPool coordination
- **Network Threading (EventLoopGroup)**: Internal HTTP processing, separate from user threading
  - Shared EventLoopGroup with dynamic thread count (ProcessInfo.processInfo.processorCount)
  - Prevents memory leaks from per-request EventLoopGroup creation
  - Does NOT affect user-controlled crawler concurrency

### Performance Improvements Applied
- **TaskPool Optimization**: Replaced O(n) array with O(1) Set+HashMap for URL tracking
- **Regex Caching**: HTMLLinkParser compiles regex once, reuses across all parsing operations
- **Shared EventLoopGroup**: All HTTP requests share one EventLoopGroup instead of creating new ones
- **Thread Timing**: Reduced thread warmup delay from 0.5s to 0.1s for faster processing

### Energy Efficiency Gains
- Reduced object creation/destruction overhead
- CPU optimization through Set-based URL deduplication
- Better resource management with shared networking components

### Key Performance Insights
- TaskPool uses Set for O(1) URL lookups instead of O(n) array search
- HTMLLinkParser regex is compiled once and cached
- NetworkLoader prevents memory leaks while maintaining thread safety
- User-controlled concurrency (-t option) operates independently from internal network threading

## System Architecture Deep Dive

### Clear Vision and Design Philosophy

The crawler is architected as a **production-grade web discovery tool** with the following core principles:

#### **1. Scalability First**
- **Large Network Support**: Designed to handle websites with 10,000+ pages efficiently
- **Memory Optimization**: O(1) URL deduplication prevents memory explosion on large sites
- **Resource Management**: Shared EventLoopGroup prevents resource exhaustion

#### **2. Complete Traceability**
- **Full Provenance**: Every URL tracks its complete discovery history
- **Multi-Source Discovery**: URLs found from multiple pages maintain all parent relationships
- **Audit Trail**: Even filtered/blacklisted URLs maintain relationship data for analysis

#### **3. Production Reliability**
- **Graceful Interruption**: SIGINT handling ensures output generation even on premature termination
- **Error Resilience**: HTTP errors don't stop crawling, all responses are recorded
- **Resource Cleanup**: Proper memory management and network resource cleanup

#### **4. Performance Transparency**
- **Detailed Metrics**: Response times, cache analysis, and HTTP status tracking
- **Real-time Monitoring**: Verbose mode provides live crawling progress
- **Performance Tuning**: Thread count optimization with measurable impact

### Advanced ID System Architecture

#### **URL Identity Management**
```swift
// Core ID generation logic in TaskPool.swift
private func getId(forString link: String) -> UInt {
    if let existingId = urlToIdMap[link] {
        return existingId  // O(1) lookup for existing URLs
    }
    let newId = nextId
    nextId += 1
    urlSet.insert(link)      // O(1) deduplication
    urlToIdMap[link] = newId // O(1) mapping
    return newId
}
```

#### **Parent-Child Relationship Management**
- **Multi-Parent Architecture**: URLs discovered from multiple sources maintain all relationships
- **Blacklist Preservation**: Filtered URLs keep parent data for network analysis
- **Discovery Chain Tracking**: Complete trace from root URL to any discovered page

#### **Task Lifecycle Management**
```
URL Discovery → ID Assignment → Task Creation → State Transitions
     ↓              ↓              ↓              ↓
Set<String>    urlToIdMap     CrawlerTask    openTask → processTask → finishTask
                   ↓              ↓              ↓
               Sequential ID   Parent Tracking  Output Generation
```

### Advanced Features and Capabilities

#### **1. Cache Control Analysis**
- **HTTP Cache Headers**: Extracts and analyzes Cache-Control headers
- **Cacheable Detection**: Identifies no-cache, no-store directives
- **Max-Age Extraction**: Parses max-age values for cache optimization analysis

#### **2. HTML Link Processing**
- **Regex Optimization**: Compiled regex cached for performance (`NSRegularExpression`)
- **URL Normalization**: Handles relative URLs, fragments, and encoding
- **Same-Domain Filtering**: Automatically filters external domains

#### **3. Network Optimization**
- **Connection Reuse**: Shared EventLoopGroup across all requests
- **Concurrent Processing**: User-controlled thread pool for parallel crawling
- **Request Timing**: Precise millisecond timing for performance analysis

#### **4. Output Generation Strategy**
- **Complete Coverage**: All discovered URLs included (processed, blacklisted, errored)
- **Structured Format**: Space-separated columns for easy parsing and analysis
- **Relationship Preservation**: Parent-child data enables network visualization

### Large Network Handling

#### **Memory Efficiency**
- **URL Deduplication**: O(1) Set-based duplicate detection
- **Task State Separation**: Efficient HashMap-based task management
- **Lazy Loading**: Tasks created only when URLs are discovered

#### **Processing Efficiency**
- **Concurrent Crawling**: Configurable thread pool for parallel processing
- **State Machine**: Clear task state transitions prevent processing errors
- **Resource Pooling**: Shared network resources across all requests

#### **Analysis Capabilities**
The ID system enables sophisticated network analysis:

1. **Site Structure Mapping**: Understand navigation hierarchies
2. **Broken Link Detection**: Identify which pages contain errors
3. **Performance Bottlenecks**: Find slow-loading pages and their sources
4. **Cache Optimization**: Analyze cache headers for optimization opportunities
5. **Content Discovery**: Track how content is linked and accessed

### Real-World Use Cases

#### **1. Website Auditing**
- Track all pages and their discovery paths
- Identify broken links and their sources
- Analyze cache configuration across the site

#### **2. SEO Analysis**
- Map internal linking structure
- Identify orphaned pages (no parent links)
- Analyze site depth and navigation efficiency

#### **3. Performance Monitoring**
- Measure response times across the site
- Identify performance bottlenecks
- Track cache effectiveness

#### **4. Security Assessment**
- Discover all accessible pages
- Identify unintended public content
- Map site attack surface

The architecture provides a solid foundation for web analysis, security assessment, and performance monitoring at scale.

## Testing

### Test Suite Overview
The project includes a comprehensive test suite located in the `crawlerTests/` directory that validates all system functionality including network requests, threading, argument parsing, and output generation.

### Test Categories
1. **System Integration Tests** (`CrawlerSystemTests.swift`)
   - Command-line argument parsing with all options (-t, -v, -filter, -limit, -o)
   - Thread count configuration and validation
   - End-to-end crawling with mock HTTP responses
   - Filter and limit functionality
   - Output file generation and validation
   - Error handling for invalid URLs and HTTP errors

2. **Performance Tests** (`CrawlerPerformanceTests.swift`)
   - Threading performance comparison (1, 2, 4, 8+ threads)
   - Memory usage testing with high thread counts
   - TaskPool performance with large URL sets (10,000+ URLs)
   - Large website simulation and stress testing
   - Performance benchmarking and timing measurements

3. **Edge Case Tests** (`CrawlerEdgeCaseTests.swift`)
   - Empty and malformed HTML response handling
   - Relative URL resolution and special characters
   - Filter edge cases and limit boundary conditions
   - Output file path handling (tilde expansion, non-existent directories)
   - Threading edge cases (0 threads, very high thread counts)
   - Cache control header processing

### Test Infrastructure
- **MockHTTPServer**: Custom HTTP server for simulating network requests
- **TestCrawler**: Specialized crawler subclass for testing with completion callbacks
- **Comprehensive Coverage**: Tests validate the entire system, not just individual methods

### Running Tests
```bash
# Using the test runner script
cd crawlerTests
./run_tests.sh

# Using Xcode
xcodebuild test -project crawler.xcodeproj -scheme crawler -destination 'platform=macOS'
```

### Thread Testing Specifics
The test suite extensively validates the `-t` thread argument:
- Tests thread counts from 1 to 20+ threads
- Verifies concurrent processing of multiple URLs
- Measures performance differences between thread configurations
- Ensures thread safety and proper resource management
- Validates that the specified number of threads is actually utilized

## Development Notes

- Uses Xcode project structure with manual file management
- Swift 5.0 compatibility
- macOS 10.15+ deployment target
- Hardened runtime enabled for security
- **Comprehensive test suite implemented** with system-level integration tests
- All optimizations maintain 100% backward compatibility
- Threading model preserves original design: user controls crawler concurrency, internal networking optimized separately