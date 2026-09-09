//
//  NetworkLoader.swift
//  crawler
//
//  Created by Benjamin Rannow on 06.09.22.
//

import Foundation
import SwiftyRequest
import AsyncHTTPClient
import NIOHTTP1
import NIO

class NetworkLoader
{
    var delegate: NetworkLoaderDelegate?
    var eventLoopGroup: MultiThreadedEventLoopGroup?

    /// Total attempts per URL, including the first. 1 disables retrying.
    var maxAttempts: UInt = 3

    // Shared EventLoopGroup for all network operations - use system core count or default to 4
    private static let sharedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: ProcessInfo.processInfo.processorCount > 0 ? ProcessInfo.processInfo.processorCount : 4)

    /// Without these SwiftyRequest passes `timeout: nil`, which async-http-client
    /// reads as "wait forever". A crawler must never park a slot on a dead peer.
    private static let timeouts = HTTPClient.Configuration.Timeout(
        connect: .seconds(10),
        read: .seconds(30)
    )

    deinit {
        // Clean up individual EventLoopGroup if it exists
        if let elg = eventLoopGroup {
            try? elg.syncShutdownGracefully()
        }
    }

    func setDelegate(delegate: NetworkLoaderDelegate?) {
        self.delegate = delegate
    }

    func load(withTask crawlerTask: CrawlerTask) -> Void
    {
        self.attempt(task: crawlerTask, attempt: 1)
    }

    /// One HTTP attempt.
    ///
    /// THE LIFETIME RULE THIS METHOD EXISTS TO ENFORCE -- read before editing.
    /// `RestRequest` owns its own `HTTPClient` (SwiftyRequest RestRequest.swift:401)
    /// and tears it down in `deinit` via a BLOCKING `syncShutdown()`. Neither
    /// `responseString` nor the `whenComplete` closure beneath it captures the
    /// RestRequest, so while it was only a local `let` here it was deallocated the
    /// instant this method returned -- shutting down the HTTP client while its own
    /// request was still in flight. The request then failed with `.cancelled` /
    /// `.alreadyShutdown` and no HTTP response, which the old code reported as a
    /// fabricated 500. At -t 1 the response usually won that race; at -t 10 it did
    /// not, which is precisely why the failures looked like a server-side
    /// concurrency bug and sent us auditing the server instead of this file.
    ///
    /// So: the closure holds the request strongly via its capture list, and the
    /// LAST reference is dropped on a Dispatch global queue -- never on a NIO
    /// event-loop thread (a blocking syncShutdown there deadlocks) and never on
    /// main (it would stall the queue that drives the crawl loop).
    private func attempt(task crawlerTask: CrawlerTask, attempt: UInt) -> Void
    {
        let request = RestRequest(
            method: HTTPMethod.get,
            url: crawlerTask.url.absoluteString,
            insecure: true,
            timeout: NetworkLoader.timeouts,
            eventLoopGroup: NetworkLoader.sharedEventLoopGroup
        )
        request.headerParameters.removeAll()
        request.acceptType = "*/*"
        request.productInfo = "BR-Crawler: 1.0 / site-crawler"
        request.contentType = nil
        let start = DispatchTime.now()

        request.responseString { [request] result in

            let nanoTime = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
            let timeInterval = Double(nanoTime) / 1_000_000

            switch result {
            case .success(let response):
                self.dispose(request)
                self.complete(task: crawlerTask, html: response.body, headers: response.headers, code: response.status.code, requestTimeMS: timeInterval, attempts: attempt)

            case .failure(let error):
                // The server DID answer, it just answered with an error status.
                // That is a real result: report it and never retry it.
                if let response = error.response {
                    self.dispose(request)
                    self.complete(task: crawlerTask, html: "", headers: response.headers, code: response.status.code, requestTimeMS: timeInterval, attempts: attempt)
                    return
                }

                // No HTTP response at all -- transport level.
                let reason = NetworkLoader.describe(error)
                self.dispose(request)

                if attempt < self.maxAttempts && NetworkLoader.isRetryable(error) {
                    // Exponential backoff with jitter, scheduled off the event loop.
                    let delay = pow(2.0, Double(attempt - 1)) * 0.25 + Double.random(in: 0...0.1)
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
                        self.attempt(task: crawlerTask, attempt: attempt + 1)
                    }
                    return
                }

                self.complete(task: crawlerTask, html: "", headers: HTTPHeaders(), code: 0, requestTimeMS: timeInterval, attempts: attempt, transportError: reason)
            }
        }
    }

    /// Hand the last reference to a Dispatch worker so `RestRequest.deinit` ->
    /// `HTTPClient.syncShutdown()` runs somewhere it is allowed to block.
    /// Dispatch global queues never run on NIO's event-loop threads.
    private func dispose(_ request: RestRequest) -> Void
    {
        DispatchQueue.global(qos: .utility).async {
            withExtendedLifetime(request) { }
        }
    }

    /// Retry only what a retry can plausibly fix. A refused connection or a broken
    /// TLS handshake is usually transient (listener saturated, pool churn); a
    /// malformed URL never is, and retrying it just triples the work.
    private static func isRetryable(_ error: Error) -> Bool
    {
        guard let clientError = NetworkLoader.underlyingClientError(error) else {
            // Unknown transport failure. TLS handshake errors arrive as NIOSSL
            // errors rather than HTTPClientError, and those are worth another go.
            return true
        }

        switch clientError {
        case .invalidURL, .emptyHost, .emptyScheme,
             .redirectLimitReached, .redirectCycleDetected:
            return false
        default:
            return true
        }
    }

    private static func describe(_ error: Error) -> String
    {
        if let clientError = NetworkLoader.underlyingClientError(error) {
            switch clientError {
            case .readTimeout:            return "readTimeout"
            case .remoteConnectionClosed: return "remoteConnectionClosed"
            case .cancelled:              return "cancelled"
            case .alreadyShutdown:        return "clientAlreadyShutdown"
            case .invalidURL:             return "invalidURL"
            case .emptyHost:              return "emptyHost"
            case .emptyScheme:            return "emptyScheme"
            case .redirectLimitReached:   return "redirectLimitReached"
            case .redirectCycleDetected:  return "redirectCycleDetected"
            default:                      return "httpClient(\(clientError))"
            }
        }

        // TLS and socket failures do not arrive as HTTPClientError -- they are
        // NIOSSL / NIO connection errors. Map them to SHORT STABLE TOKENS so the
        // Error column can be grouped with `sort | uniq -c`; a raw
        // String(describing:) embeds host, port and nested nils and every row
        // looks unique, which defeats the point of having the column.
        let raw = String(describing: error)
        if raw.contains("NIOConnectionError") {
            return "connectionFailed"
        }
        if raw.contains("NIOSSLError") || raw.contains("handshake") || raw.contains("sslError") {
            return "tlsHandshakeFailed"
        }
        if raw.contains("ChannelError.connectTimeout") || raw.contains("connectTimeout") {
            return "connectTimeout"
        }

        let text = raw
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "\n", with: "_")
        return text.count > 80 ? String(text.prefix(80)) : text
    }

    private static func underlyingClientError(_ error: Error) -> HTTPClientError?
    {
        if let clientError = error as? HTTPClientError {
            return clientError
        }
        // RestError is a struct with a PRIVATE internal case enum, so it cannot be
        // pattern matched; it exposes the underlying transport failure as `.error`.
        if let restError = error as? RestError,
           let nested = restError.error as? HTTPClientError {
            return nested
        }
        return nil
    }

    func complete(task: CrawlerTask, html: String, headers: HTTPHeaders, code: UInt, requestTimeMS: Double, attempts: UInt = 1, transportError: String? = nil) -> Void
    {
        if (self.delegate != nil) {
            let newUrls = HTMLLinkParser.parse(html: html, baseUrl: (self.delegate?.getBaseUrl(loader: self, task: task))!)
            DispatchQueue.main.async {

                task.code = code
                task.header = headers
                task.requestTime = requestTimeMS
                task.attempts = attempts
                task.transportError = transportError

                // No need to shutdown shared EventLoopGroup
                self.delegate!.complete(loader: self, task: task, urls: newUrls, html: html)
            }
        }
    }
}
