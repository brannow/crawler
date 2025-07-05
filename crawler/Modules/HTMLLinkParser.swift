//
//  HTMLLinkParser.swift
//  crawler
//
//  Created by Benjamin Rannow on 06.09.22.
//

import Foundation

extension String {
    func substring(with nsrange: NSRange) -> Substring? {
        guard let range = Range(nsrange, in: self) else { return nil }
        return self[range]
    }
    
    func encodeUrl() -> String?
    {
        return self.addingPercentEncoding( withAllowedCharacters: NSCharacterSet.urlQueryAllowed)
    }
    func decodeUrl() -> String?
    {
        return self.removingPercentEncoding
    }
}

class HTMLLinkParser
{
    // Cache compiled regex for better performance
    private static let linkRegex = try! NSRegularExpression(pattern: #"<a\s+(?:[^>]*?\s+)?href=(["\'])(.*?)\1"#, options: .anchorsMatchLines)
    
    static func parse(html: String, baseUrl: URL) -> Set<String>
    {
        let stringRange = NSRange(location: 0, length: html.utf16.count)
        let matches = linkRegex.matches(in: html, range: stringRange)
        
        var result: Set<String> = []
        for match in matches {
            for rangeIndex in 1 ..< match.numberOfRanges {
                if (rangeIndex == 2) {
                    let nsRange = match.range(at: rangeIndex)
                    guard !NSEqualRanges(nsRange, NSMakeRange(NSNotFound, 0)) else { continue }
                    let substr = html.substring(with: nsRange)
                    var link = String(substr ?? "")
                    link = link.replacingOccurrences(of: "&amp;", with: "&").decodeUrl() ?? link
                    
                    // remove unused requets stuff like /link/awd/ad#asdadw
                    if (link.contains("#")) {
                        link = link.components(separatedBy: "#")[0] 
                    }
                    
                    var subUrl: String? = nil
                    if (link.starts(with: "http") && link.contains("://" + (baseUrl.host ?? "--NOTFOUND-"))) {
                        if (link.starts(with: "https://" + baseUrl.host!) || link.starts(with: "http://" + baseUrl.host!)) {
                            subUrl = link
                        }
                    } else if (link.starts(with: "/")) {
                        subUrl = baseUrl.absoluteString + link
                    }
                    
                    if (subUrl != nil) {
                        result.insert(subUrl!)
                    }
                }
            }
        }
        
        return result
    }
}
