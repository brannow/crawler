//
//  CrawlerResult.swift
//  crawler
//
//  Created by Benjamin Rannow on 06.09.22.
//

import Foundation
import NIOHTTP1

class CrawlerTask {
    var url: URL
    var parentId: Set<UInt> = []
    var header: HTTPHeaders? = nil
    var code: UInt = 0
    var requestTime: Double = 0.0
    var id: UInt? = nil
    var matchedKeywords: [String] = []
    
    init (url: URL) {
        self.url = url
    }
}
