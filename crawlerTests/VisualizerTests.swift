//
//  VisualizerTests.swift
//  crawlerTests
//

import XCTest

final class VisualizerTests: XCTestCase {

    private let placeholders = Visualizer.placeholders

    private let sampleReport = """
    ID Parent_Ids HTTP_CODE Cache_Control Max_Age Request_Time_MS URL Keywords Attempts Error Expires Bytes
    0 0 200 max-age=300 300 12.5 https://example.com/ - 1 - - 1024
    1 0 200 private,_no-store -1 8.0 https://example.com/a/ - 1 - - 512
    """

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("VisualizerTests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    /// Pulls an embedded report literal back out of the page and JSON-decodes it.
    private func embeddedReport(in html: String, variable: String = "CRAWL_REPORT") throws -> String {
        let start = try XCTUnwrap(html.range(of: "window.\(variable) = "))
        let end = try XCTUnwrap(html.range(of: ";\n", range: start.upperBound..<html.endIndex))
        let literal = String(html[start.upperBound..<end.lowerBound])
        XCTAssertFalse(literal.contains("<"), "a raw '<' in the literal could close the <script> early")
        return try JSONDecoder().decode(String.self, from: Data(literal.utf8))
    }

    func testTemplateHasEachPlaceholderExactlyOnce() {
        // A second occurrence would either duplicate the multi-MB payload or
        // leave a bare placeholder behind as a JS syntax error.
        for placeholder in placeholders {
            XCTAssertEqual(VisualizerTemplate.html.components(separatedBy: placeholder).count - 1, 1, placeholder)
        }
    }

    func testRenderFillsEveryPlaceholder() {
        let html = Visualizer.render(report: sampleReport, name: "report.txt")
        for placeholder in placeholders {
            XCTAssertFalse(html.contains(placeholder), placeholder)
        }
        XCTAssertTrue(html.contains(D3Hierarchy.source))
    }

    func testRenderLoadsNothingExternal() {
        let html = Visualizer.render(report: sampleReport, name: "report.txt")
        XCTAssertFalse(html.contains("<script src"))
        XCTAssertFalse(html.contains("<link"))
    }

    func testReportRoundTripsByteForByte() throws {
        let html = Visualizer.render(report: sampleReport, name: "report.txt")
        XCTAssertEqual(try embeddedReport(in: html), sampleReport)
    }

    func testHostileReportContentRoundTripsAndCannotEscapeTheScript() throws {
        // "</script>", line/paragraph separators, non-ASCII, quotes, backslashes,
        // and EVERY placeholder name inside BOTH reports' data: with two payloads,
        // only a single-pass fill guarantees inserted data is never expanded.
        let names = placeholders.joined(separator: "_")
        let hostile = sampleReport + "\n2 0 200 - -1 1.0 https://example.com/x</script><script>alert(1)</script> - 1 \"q\\\" - 0" +
            "\n3 0 200 - -1 1.0 https://example.com/stra\u{00DF}e\u{2028}\u{2029} \(names) 1 - - 0"
        let hostileBase = hostile + "\n4 0 404 - -1 1.0 https://example.com/old \(names) 1 - - 0"
        let html = Visualizer.render(report: hostile, name: "r</script>.txt", baseline: hostileBase, baselineName: "b</script>.txt")
        XCTAssertEqual(try embeddedReport(in: html), hostile)
        XCTAssertEqual(try embeddedReport(in: html, variable: "CRAWL_BASELINE"), hostileBase)
        XCTAssertEqual(try embeddedReport(in: html, variable: "CRAWL_BASELINE_NAME"), "b</script>.txt")
        XCTAssertFalse(html.contains("alert(1)</script>"))
        XCTAssertEqual(html.components(separatedBy: D3Hierarchy.source).count - 1, 1)
    }

    func testWithoutBaselineTheBaselineIsNull() {
        let html = Visualizer.render(report: sampleReport, name: "report.txt")
        XCTAssertTrue(html.contains("window.CRAWL_BASELINE = null;"))
        XCTAssertTrue(html.contains("window.CRAWL_BASELINE_NAME = null;"))
    }

    func testWriteEmbedsBaselineNamedAfterItsFile() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let current = tempDir.appendingPathComponent("v14.txt"), base = tempDir.appendingPathComponent("v13.txt")
        try sampleReport.write(to: current, atomically: true, encoding: .utf8)
        let baseText = sampleReport.replacingOccurrences(of: "example.com", with: "old.example.com")
        try baseText.write(to: base, atomically: true, encoding: .utf8)

        let file = try Visualizer.write(reportAt: current.path, to: tempDir.path, compareWith: base.path)
        let html = try String(contentsOf: file, encoding: .utf8)
        XCTAssertEqual(file.lastPathComponent, "v14.html")
        XCTAssertEqual(try embeddedReport(in: html, variable: "CRAWL_BASELINE"), baseText)
        XCTAssertEqual(try embeddedReport(in: html, variable: "CRAWL_BASELINE_NAME"), "v13.txt")
    }

    func testMissingBaselineThrows() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let current = tempDir.appendingPathComponent("v14.txt")
        try sampleReport.write(to: current, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try Visualizer.write(reportAt: current.path, to: tempDir.path, compareWith: tempDir.appendingPathComponent("nope.txt").path))
    }

    func testWriteCreatesDirectoryAndNamesFileAfterReport() throws {
        let reportURL = tempDir.appendingPathComponent("in/sbb-crawl.txt")
        try FileManager.default.createDirectory(at: reportURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try sampleReport.write(to: reportURL, atomically: true, encoding: .utf8)

        let out = tempDir.appendingPathComponent("out/nested")
        let file = try Visualizer.write(reportAt: reportURL.path, to: out.path)

        XCTAssertEqual(file.lastPathComponent, "sbb-crawl.html")
        let html = try String(contentsOf: file, encoding: .utf8)
        XCTAssertEqual(try embeddedReport(in: html), sampleReport)
        XCTAssertTrue(html.contains("window.CRAWL_REPORT_NAME = \"sbb-crawl.txt\";"))
    }

    func testMissingReportThrows() {
        XCTAssertThrowsError(try Visualizer.write(reportAt: tempDir.appendingPathComponent("nope.txt").path, to: tempDir.path)) { error in
            guard case Visualizer.VisualizerError.unreadableReport = error else { return XCTFail("unexpected \(error)") }
        }
    }

    func testEmptyReportThrows() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let reportURL = tempDir.appendingPathComponent("empty.txt")
        try "  \n".write(to: reportURL, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try Visualizer.write(reportAt: reportURL.path, to: tempDir.path)) { error in
            guard case Visualizer.VisualizerError.emptyReport = error else { return XCTFail("unexpected \(error)") }
        }
    }
}
