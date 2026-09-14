//
//  NetworkLoader.swift
//  crawler
//
//  Created by Benjamin Rannow on 06.09.22.
//

import Foundation
import AsyncHTTPClient
import NIOHTTP1
import NIOSSL
import NIO

class NetworkLoader
{
    var delegate: NetworkLoaderDelegate?
    var eventLoopGroup: MultiThreadedEventLoopGroup?

    /// Total attempts per URL, including the first. 1 disables retrying.
    var maxAttempts: UInt = 3

    // Shared EventLoopGroup for all network operations - use system core count or default to 4
    private static let sharedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: ProcessInfo.processInfo.processorCount > 0 ? ProcessInfo.processInfo.processorCount : 4)

    /// Without these async-http-client reads "no timeout" and a crawl could park
    /// a thread slot on a dead peer indefinitely.
    private static let timeouts = HTTPClient.Configuration.Timeout(
        connect: .seconds(10),
        read: .seconds(30)
    )

    /// One long-lived HTTPClient for the whole process, talking to
    /// AsyncHTTPClient directly instead of through SwiftyRequest's RestRequest.
    ///
    /// Two reasons this is no longer a RestRequest:
    /// 1. `redirectConfiguration: .disallow`, on purpose. RestRequest builds its
    ///    own HTTPClient internally with no way to override redirect handling,
    ///    so a 3xx was always followed silently -- the crawler never saw the
    ///    redirect, never recorded it, and never queued its target as its own
    ///    discovered URL. That made redirect chains invisible to exactly the
    ///    migration/link-rot audits this tool exists for (see README). Now a
    ///    3xx is a terminal, recorded result and its Location header is queued
    ///    like any other discovered link -- see attempt(task:attempt:) below.
    /// 2. It sidesteps the old per-request RestRequest lifetime hazard
    ///    entirely (formerly documented here in detail: a fresh HTTPClient
    ///    constructed per request, torn down by a blocking syncShutdown() in
    ///    its deinit, racing the very request it was still serving). A single
    ///    shared client created once has nothing to race -- it lives until the
    ///    process exits, and exit() doesn't run Swift deinitializers anyway.
    private static let sharedHTTPClient = HTTPClient(
        eventLoopGroupProvider: .shared(NetworkLoader.sharedEventLoopGroup),
        configuration: HTTPClient.Configuration(
            certificateVerification: .none,
            redirectConfiguration: .disallow,
            timeout: NetworkLoader.timeouts
        )
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

    /// One HTTP attempt, redirects included as a terminal result rather than
    /// something AsyncHTTPClient resolves on our behalf.
    private func attempt(task crawlerTask: CrawlerTask, attempt: UInt) -> Void
    {
        var headers = HTTPHeaders()
        headers.add(name: "Accept", value: "*/*")
        headers.add(name: "User-Agent", value: "BR-Crawler: 1.0 / site-crawler")

        guard let request = try? HTTPClient.Request(url: crawlerTask.url.absoluteString, method: .GET, headers: headers) else {
            self.complete(task: crawlerTask, html: "", headers: HTTPHeaders(), code: 0, requestTimeMS: 0, attempts: attempt, transportError: "invalidURL")
            return
        }

        let start = DispatchTime.now()

        NetworkLoader.sharedHTTPClient.execute(request: request).whenComplete { result in

            let nanoTime = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
            let timeInterval = Double(nanoTime) / 1_000_000

            switch result {
            case .success(let response):
                // Every real HTTP response (2xx through 5xx) lands here --
                // unlike SwiftyRequest, AsyncHTTPClient doesn't artificially
                // fail the future for a non-2xx status. `.failure` below is
                // reserved for genuine transport failures.
                let bytes = response.body?.readableBytes ?? 0

                switch response.status.code {
                case 200..<300:
                    let html = NetworkLoader.decodeBody(response.body, headers: response.headers)
                    self.complete(task: crawlerTask, html: html, headers: response.headers, code: response.status.code, requestTimeMS: timeInterval, attempts: attempt, bytes: bytes)

                case 300..<400:
                    // A real answer, never retried -- but there's no page here
                    // to scan for links, just a Location to treat as the one
                    // URL this page discovered (dropped if it points off-host,
                    // same as any other cross-host link).
                    let discovered = self.discoverRedirectTarget(from: response.headers, task: crawlerTask)
                    self.complete(task: crawlerTask, html: "", headers: response.headers, code: response.status.code, requestTimeMS: timeInterval, attempts: attempt, bytes: bytes, discoveredUrls: discovered)

                default:
                    // 4xx/5xx: a real answer, never retried. The error page's
                    // own links were never crawled before this change either.
                    self.complete(task: crawlerTask, html: "", headers: response.headers, code: response.status.code, requestTimeMS: timeInterval, attempts: attempt, bytes: bytes, discoveredUrls: [])
                }

            case .failure(let error):
                // No HTTP response at all -- transport level.
                let reason = NetworkLoader.describe(error)

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

    /// Resolves a redirect's `Location` header into the one URL this response
    /// discovered. `Location` may be relative (rare in practice, still legal),
    /// so this does real RFC 3986 resolution against the request URL rather
    /// than HTMLLinkParser's limited absolute-or-root-relative string match --
    /// that shortcut is acceptable for editorial `<a href>` content but not
    /// appropriate here. Off-host targets are dropped, same as any other
    /// cross-host link the crawler encounters.
    private func discoverRedirectTarget(from headers: HTTPHeaders, task: CrawlerTask) -> Set<String> {
        guard let location = headers["Location"].first,
              let resolved = URL(string: location, relativeTo: task.url)?.absoluteURL,
              let baseUrl = self.delegate?.getBaseUrl(loader: self, task: task),
              resolved.host == baseUrl.host
        else {
            return []
        }

        return [resolved.absoluteString]
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
        return error as? HTTPClientError
    }

    /// Decodes a response body using the charset from its Content-Type header
    /// (defaulting to UTF-8, with an ISO-8859-1 special case -- the same rule
    /// SwiftyRequest applied). Falls back to a lossy UTF-8 decode rather than
    /// dropping the body entirely on a decode failure, so a charset mismatch
    /// no longer silently zeroes out link/keyword discovery for that page.
    private static func decodeBody(_ body: ByteBuffer?, headers: HTTPHeaders) -> String {
        guard let body = body, let bytes = body.getBytes(at: 0, length: body.readableBytes) else {
            return ""
        }

        let encoding = NetworkLoader.characterEncoding(from: headers["content-type"].first)
        return String(bytes: bytes, encoding: encoding) ?? String(decoding: bytes, as: UTF8.self)
    }

    private static func characterEncoding(from contentType: String?) -> String.Encoding {
        guard let text = contentType,
              let regex = try? NSRegularExpression(pattern: "(?<=charset=).*?(?=$|;|\\s)", options: [.caseInsensitive]),
              let match = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).last,
              let range = Range(match.range, in: text) else {
            return .utf8
        }

        let charset = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: "\"").union(.whitespaces))
        switch charset.lowercased() {
        case "iso-8859-1": return .isoLatin1
        default: return .utf8
        }
    }

    func complete(task: CrawlerTask, html: String, headers: HTTPHeaders, code: UInt, requestTimeMS: Double, attempts: UInt = 1, transportError: String? = nil, bytes: Int = 0, discoveredUrls: Set<String>? = nil) -> Void
    {
        if (self.delegate != nil) {
            // discoveredUrls is only ever passed explicitly for a redirect
            // (see attempt(task:attempt:)); everything else discovers links by
            // parsing html as before.
            let newUrls = discoveredUrls ?? HTMLLinkParser.parse(html: html, baseUrl: (self.delegate?.getBaseUrl(loader: self, task: task))!)
            DispatchQueue.main.async {

                task.code = code
                task.header = headers
                task.requestTime = requestTimeMS
                task.attempts = attempts
                task.transportError = transportError
                task.bytes = bytes

                // No need to shutdown shared EventLoopGroup
                self.delegate!.complete(loader: self, task: task, urls: newUrls, html: html)
            }
        }
    }
}
