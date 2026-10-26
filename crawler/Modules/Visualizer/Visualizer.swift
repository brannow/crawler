//
//  Visualizer.swift
//  crawler
//

import Foundation

/// `crawler visual <report> -o <dir>`: turns a report file into one
/// self-contained HTML page (treemap / circle-pack map of the crawl).
///
/// Swift only *embeds* here -- it never parses the report. The page's own JS
/// parses the raw text, so the report format has exactly one reader to keep
/// in sync instead of a Swift and a JS copy of the same parser.
///
/// Never calls `exit()`: this file compiles into the test bundle too (see
/// CLAUDE.md, `Crawler.exitHandler`). Errors are thrown; main.swift maps them
/// to a message and a non-zero exit code.
enum Visualizer {

    enum VisualizerError: Error, CustomStringConvertible {
        case unreadableReport(path: String, underlying: Error)
        case emptyReport(path: String)
        case cannotWrite(path: String, underlying: Error)

        var description: String {
            switch self {
            case .unreadableReport(let path, let underlying):
                return "cannot read report \(path): \(underlying.localizedDescription)"
            case .emptyReport(let path):
                return "report \(path) is empty"
            case .cannotWrite(let path, let underlying):
                return "cannot write \(path): \(underlying.localizedDescription)"
            }
        }
    }

    /// Every placeholder in VisualizerTemplate.html; each occurs exactly once.
    static let placeholders = [
        "/*__D3_HIERARCHY__*/",
        "__CRAWL_REPORT_NAME_JSON__", "__CRAWL_REPORT_JSON__",
        "__CRAWL_BASELINE_NAME_JSON__", "__CRAWL_BASELINE_JSON__",
    ]

    /// Fills the template in ONE pass over the template itself: placeholder
    /// positions are located in the template, then template slices and values
    /// are concatenated. With two embedded reports, sequential replace calls
    /// could expand placeholder-looking text inside the first report's data;
    /// here inserted data is never scanned again.
    /// `baseline` is the optional older crawl the page diffs against (by URL).
    static func render(report: String, name: String, baseline: String? = nil, baselineName: String? = nil) -> String {
        let template = VisualizerTemplate.html
        let values: [String: String] = [
            "/*__D3_HIERARCHY__*/": D3Hierarchy.source,
            "__CRAWL_REPORT_NAME_JSON__": jsStringLiteral(name),
            "__CRAWL_REPORT_JSON__": jsStringLiteral(report),
            "__CRAWL_BASELINE_NAME_JSON__": baseline == nil ? "null" : jsStringLiteral(baselineName ?? "baseline"),
            "__CRAWL_BASELINE_JSON__": baseline.map { jsStringLiteral($0) } ?? "null",
        ]
        let found = placeholders
            .compactMap { key in template.range(of: key).map { (range: $0, value: values[key]!) } }
            .sorted { $0.range.lowerBound < $1.range.lowerBound }
        var html = ""
        var cursor = template.startIndex
        for item in found {
            html += template[cursor..<item.range.lowerBound]
            html += item.value
            cursor = item.range.upperBound
        }
        html += template[cursor...]
        return html
    }

    /// Writes `<outputDirectory>/<report name without extension>.html`, creating
    /// the directory if needed. Named after the report rather than `index.html`
    /// so `-o ./` can't clobber an unrelated index.html, and several reports can
    /// share one output directory.
    /// With `baselinePath`, the older report is embedded too and the page
    /// opens in its Diff colour mode.
    @discardableResult
    static func write(reportAt reportPath: String, to outputDirectory: String, compareWith baselinePath: String? = nil) throws -> URL {
        let (reportURL, report) = try readReport(at: reportPath)
        let baseline = try baselinePath.map { try readReport(at: $0) }

        let dirURL = URL(fileURLWithPath: (outputDirectory as NSString).expandingTildeInPath, isDirectory: true)
        let fileURL = dirURL.appendingPathComponent(reportURL.deletingPathExtension().lastPathComponent + ".html")
        let html = render(report: report, name: reportURL.lastPathComponent,
                          baseline: baseline?.text, baselineName: baseline?.url.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw VisualizerError.cannotWrite(path: fileURL.path, underlying: error)
        }
        return fileURL
    }

    private static func readReport(at path: String) throws -> (url: URL, text: String) {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw VisualizerError.unreadableReport(path: url.path, underlying: error)
        }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw VisualizerError.emptyReport(path: url.path)
        }
        return (url, text)
    }

    /// A JS string literal safe to drop inside an inline <script>: JSON string
    /// encoding, plus "<" escaped so a "</script>" in the data can't end the
    /// script element early. U+2028/U+2029 are escaped too -- legal in JS
    /// strings only since ES2019, so older engines would choke on them raw.
    static func jsStringLiteral(_ value: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        // Encoding a String cannot fail; the fallback only satisfies the compiler.
        guard let data = try? encoder.encode(value), let json = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return json
            .replacingOccurrences(of: "<", with: "\\u003c")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }
}
