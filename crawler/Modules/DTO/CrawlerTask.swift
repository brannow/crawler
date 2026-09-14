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

    /// Why the request never produced an HTTP response (connection refused, TLS
    /// handshake failure, timeout, ...), or nil when the server did answer.
    ///
    /// This exists because `code` used to be set to a FABRICATED 500 whenever the
    /// transport failed, which is indistinguishable in the output from a real
    /// server-side 500 -- and sent us hunting for an application bug that did not
    /// exist. `code` now only ever holds a status a server actually sent; a
    /// transport failure leaves it 0 and records the reason here.
    var transportError: String? = nil

    /// How many attempts it took. 1 means it succeeded first try.
    var attempts: UInt = 0

    /// Bytes in the response body -- the exact wire byte count for any real
    /// HTTP response (2xx through 5xx), read directly off the raw ByteBuffer
    /// before any string decoding happens. 0 for transport failures, which
    /// correctly means "nothing was received."
    var bytes: Int = 0
    
    init (url: URL) {
        self.url = url
    }
}
