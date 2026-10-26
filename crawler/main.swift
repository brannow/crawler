//
//  main.swift
//  crawler
//
//  Created by Benjamin Rannow on 05.09.22.
//

import Foundation
import Dispatch

func printHelp() {
    print("""
    crawler - multi-threaded same-host web crawler

    Usage:
      ./crawler [options] <url>
      ./crawler visual <report> [-compare <baseline>] [-o <dir>]

    Options:
      -t <n>            Threads: pages fetched concurrently. Default: 1
      -v                Verbose: print progress to the console as pages are fetched.
      -filter <list>    Comma-separated substrings. Any discovered URL containing one is
                        blacklisted -- still recorded in the report, never fetched.
      -keywords <list>  Comma-separated strings. Each fetched page's HTML is scanned
                        (case-insensitive) and matches are recorded per-URL.
      -limit <n>        Stop once this many pages have been fetched or are in flight.
                        Default: 0 (unlimited)
      -retry <n>        Total attempts per URL, including the first. 1 disables retrying.
                        Only transport failures (refused connection, TLS handshake
                        failure, timeout) are retried -- an HTTP error status is a real
                        answer and is never retried. Default: 3
      -o <file>         Report file path. Without it, nothing is written to disk.
      -h, --help        Show this help.

    Visual:
      visual <report>   Render a report file as one self-contained HTML page (treemap /
                        circle-pack site map: status, click depth, cache headers).
                        Works offline, no external resources.
      -compare <file>   Older report to diff against, embedded into the same page. URLs
                        are matched by path + query (host ignored, TYPO3 cHash ignored
                        by default), never by ID.
      -o <dir>          Output directory, created if missing. Default: current directory.
                        Writes <dir>/<report name>.html.

    Example:
      ./crawler -v -t 10 -retry 3 -filter "/fileadmin/,tx_news,tx_t3events_events" -keywords "login,admin,contact" -o ~/Desktop/list.txt https://your-domain/
      ./crawler visual ~/Desktop/list.txt -o ~/Desktop/crawl-visual
      ./crawler visual ~/Desktop/v14.txt -compare ~/Desktop/v13.txt -o ~/Desktop/crawl-visual
    """)
}

// `visual` is its own mode and must be dispatched before any crawl setup: the
// crawl path below takes the LAST positional argument as the seed URL, so a
// late branch would try to crawl the report file.
func runVisual(_ arguments: CommandArgumentResult) -> Never {
    let positional = arguments.arguments.map { $0.value }
    guard positional.count >= 2 else {
        print("no report file given\n")
        printHelp()
        exit(1)
    }
    let outputDirectory = arguments.getOptionValue(key: "-o", defaultValue: ".").value ?? "."
    let compare = arguments.getOptionValue(key: "-compare")
    if compare.exist && (compare.value ?? "").isEmpty {
        print("-compare needs a report file\n")
        exit(1)
    }
    do {
        let file = try Visualizer.write(reportAt: positional[1], to: outputDirectory, compareWith: compare.exist ? compare.value : nil)
        print(file.path)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("error: \(error)\n".utf8))
        exit(1)
    }
}

signal(SIGINT, SIG_IGN)

let arguments = ArgumentParser.parse(arguments: CommandLine.arguments, config: [
    OptionType(withKey: "-t", hasValue: true),
    OptionType(withKey: "-v"),
    OptionType(withKey: "-filter", hasValue: true),
    OptionType(withKey: "-limit", hasValue: true),
    OptionType(withKey: "-o", hasValue: true),
    OptionType(withKey: "-keywords", hasValue: true),
    OptionType(withKey: "-retry", hasValue: true),
    OptionType(withKey: "-compare", hasValue: true),
    OptionType(withKey: "-h"),
    OptionType(withKey: "--help")
] )

if (arguments.hasOption(key: "-h") || arguments.hasOption(key: "--help")) {
    printHelp()
    exit(0)
}

if (arguments.arguments.first?.value == "visual") {
    runVisual(arguments)
}

let threadCount: UInt = UInt(arguments.getOptionValue(key: "-t", defaultValue: "1").value ?? "1") ?? 1
let limit: UInt = UInt(arguments.getOptionValue(key: "-limit", defaultValue: "0").value ?? "0") ?? 0
let filterString: String = arguments.getOptionValue(key: "-filter", defaultValue: "").value ?? ""
let keywordsString: String = arguments.getOptionValue(key: "-keywords", defaultValue: "").value ?? ""
let fileLocation: String = arguments.getOptionValue(key: "-o", defaultValue: "").value ?? ""
// Total attempts per URL, including the first. 1 disables retrying.
let retryCount: UInt = UInt(arguments.getOptionValue(key: "-retry", defaultValue: "3").value ?? "3") ?? 3

let crawler = Crawler(
    withThreads: threadCount,
    filter: filterString,
    keywords: keywordsString,
    limit: limit,
    verbose: arguments.hasOption(key: "-v"),
    outputFileLocation: fileLocation,
    maxAttempts: retryCount
)

let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigintSrc.setEventHandler {
    
    print("\nabort job...")
    crawler.generateOutput()
    exit(0)
}
sigintSrc.resume()

if (arguments.arguments.count > 0) {
    crawler.crawl(from: arguments.arguments.last!.value)
    RunLoop.main.run()
} else {
    print("no url given\n")
    printHelp()
}

