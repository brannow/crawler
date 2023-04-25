//
//  CacheControl.swift
//  crawler
//
//  Created by Benjamin Rannow on 25.04.23.
//

import Foundation
import NIOHTTP1

class CacheControl {
    var maxAge: Int = 0
    var cacheable: Bool = true
    
    init (headers: HTTPHeaders?) {
        let cHeader: [String] = headers?["cache-control"] ?? []
        var cachable: Bool = true
        var maxAge: Int = -1
        for header in cHeader {
            if (header.contains("no-cache") || header.contains("no-store")) {
                cachable = false;
            }
            
            if (header.contains("max-age")) {
                maxAge = getMaxAgeFromString(cacheString: header)
            }
        }
        
        self.maxAge = maxAge
        self.cacheable = cachable
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
