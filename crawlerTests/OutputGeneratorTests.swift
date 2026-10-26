//
//  OutputGeneratorTests.swift
//  crawlerTests
//

import XCTest

final class OutputGeneratorTests: XCTestCase {

    private func fieldCounts(_ output: String) -> [Int] {
        return output.split(separator: "\n").map { $0.split(separator: " ", omittingEmptySubsequences: false).count }
    }

    func testFreeTextFieldsNeverShiftColumns() {
        let pool = TaskPool()
        let seed = pool.createTask(withUrl: URL(string: "https://example.com/")!)
        _ = pool.addNew(task: seed)
        seed.code = 200
        seed.attempts = 1
        seed.matchedKeywords = ["log in", "contact\tform"]

        let failed = pool.createTask(withUrl: URL(string: "https://example.com/down")!)
        _ = pool.addNew(task: failed, parentTask: seed)
        failed.attempts = 3
        failed.transportError = "httpClient(some error with spaces\nand a newline)"

        let output = OutputGenerator.generateOutput(fromPool: pool)
        let counts = fieldCounts(output)
        XCTAssertEqual(counts.count, 3, output)
        XCTAssertEqual(Set(counts), [counts[0]], "every row must have the header's field count:\n\(output)")
        XCTAssertTrue(output.contains(" httpClient(some_error_with_spaces_and_a_newline) "), output)
        XCTAssertTrue(output.contains(" log_in,contact_form "), output)
    }

    func testFieldPlaceholderForEmptyValue() {
        XCTAssertEqual(OutputGenerator.field(""), "-")
        XCTAssertEqual(OutputGenerator.field("readTimeout"), "readTimeout")
    }
}
