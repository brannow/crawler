//
//  CacheControl.swift
//  crawler
//
//  Created by Benjamin Rannow on 25.04.23.
//

import Foundation
import NIOHTTP1

class CacheControl {
    /// Raw `Cache-Control` header value(s), joined, or "-" if the header was
    /// absent. Deliberately not collapsed into a `cacheable` bool: per RFC 9111,
    /// no header does not mean "cacheable" (it may still be heuristically
    /// cached, or not, depending on Expires/Last-Modified/ETag), and a bool
    /// can't distinguish `no-cache` (may store, must revalidate) from `no-store`
    /// (must not store). Read the raw value instead of trusting a derived flag.
    var raw: String = "-"

    /// Raw `Expires` header value, or "-" if absent. RFC 9111 gives this
    /// priority over heuristic caching when Cache-Control is missing.
    var expires: String = "-"

    /// The `max-age` directive's value, or -1 if Cache-Control was absent or
    /// didn't specify one -- both cases mean "no explicit max-age known."
    var maxAge: Int = -1

    init (headers: HTTPHeaders?) {
        let cHeader: [String] = headers?["cache-control"] ?? []
        let joinedCacheControl = CacheControl.sanitize(cHeader.joined(separator: ","))
        // A header sent with an empty value (`Cache-Control:`) still yields a
        // non-empty array (`[""]`) -- guard on the joined text, not the array,
        // or an empty field breaks the report's fixed column count.
        if !joinedCacheControl.isEmpty {
            self.raw = joinedCacheControl
            for header in cHeader where header.contains("max-age") {
                self.maxAge = getMaxAgeFromString(cacheString: header)
            }
        }

        let eHeader: [String] = headers?["expires"] ?? []
        let joinedExpires = CacheControl.sanitize(eHeader.joined(separator: ","))
        if !joinedExpires.isEmpty {
            self.expires = joinedExpires
        }
    }

    /// The report is space-separated and parsed by column position (see
    /// OutputGenerator); a raw header value like "max-age=3600, public" or an
    /// HTTP date ("Wed, 21 Oct 2025 07:28:00 GMT") contains spaces that would
    /// shift every later column. Collapse them to underscores instead of
    /// dropping the header entirely.
    private static func sanitize(_ value: String) -> String {
        return value.replacingOccurrences(of: " ", with: "_")
    }

    func getMaxAgeFromString(cacheString: String) -> Int
    {
        let pattern = #"max-age=(\d+)"#
        let regex = try! NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
        let stringRange = NSRange(location: 0, length: cacheString.utf16.count)
        let matches = regex.matches(in: cacheString, range: stringRange)
        for match in matches {
            for rangeIndex in 1 ..< match.numberOfRanges {
                let nsRange = match.range(at: rangeIndex)
                guard !NSEqualRanges(nsRange, NSMakeRange(NSNotFound, 0)) else { continue }
                let string = (cacheString as NSString).substring(with: nsRange)
                return Int(string) ?? -1
            }
        }

        return -1
    }
}
