//
//  main.swift
//  crawler
//
//  Created by Benjamin Rannow on 05.09.22.
//

import Foundation

let arguments = ArguemntParser.parse(arguments: CommandLine.arguments, config: [
    OptionType(withKey: "-t", hasValue: true),
    OptionType(withKey: "-v"),
    OptionType(withKey: "-filter", hasValue: true),
    OptionType(withKey: "-limit", hasValue: true),
    OptionType(withKey: "-o", hasValue: true)
] )

let threadCount: UInt = UInt(arguments.getOptionValue(key: "-t", defaultValue: "1").value ?? "1") ?? 1
let limit: UInt = UInt(arguments.getOptionValue(key: "-limit", defaultValue: "0").value ?? "0") ?? 0
let filterString: String = arguments.getOptionValue(key: "-filter", defaultValue: "").value ?? ""
let fileLocation: String = arguments.getOptionValue(key: "-o", defaultValue: "").value ?? ""

let crawler = Crawler(
    withThreads: threadCount,
    filter: filterString,
    limit: limit,
    verbose: arguments.hasOption(key: "-v"),
    outputFileLocation: fileLocation
)

if (arguments.arguments.count > 0) {
    crawler.crawl(from: arguments.arguments.last!.value)
    RunLoop.main.run()
} else {
    print("no url - exit")
}

