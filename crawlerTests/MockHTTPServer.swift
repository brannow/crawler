//
//  MockHTTPServer.swift
//  crawlerTests
//
//  Mock HTTP server for testing crawler functionality
//

import Foundation
import NIO
import NIOHTTP1
import NIOPosix

class MockHTTPServer {
    
    struct MockResponse {
        let statusCode: HTTPResponseStatus
        let headers: HTTPHeaders
        let body: String
        
        init(statusCode: HTTPResponseStatus = .ok, headers: HTTPHeaders = HTTPHeaders(), body: String = "") {
            self.statusCode = statusCode
            self.headers = headers
            self.body = body
        }
    }
    
    private var eventLoopGroup: MultiThreadedEventLoopGroup?
    private var channel: Channel?
    private var port: Int = 0
    private var responses: [String: MockResponse] = [:]
    
    init() {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    func start() -> Int {
        guard let eventLoopGroup = eventLoopGroup else {
            return -1
        }
        
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                let httpHandler = HTTPServerHandler(mockServer: self)
                return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                    channel.pipeline.addHandler(httpHandler)
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
        
        do {
            channel = try bootstrap.bind(host: "127.0.0.1", port: 0).wait()
            if let localAddress = channel?.localAddress {
                port = localAddress.port!
            }
            return port
        } catch {
            return -1
        }
    }
    
    func stop() {
        try? channel?.close().wait()
        try? eventLoopGroup?.syncShutdownGracefully()
        eventLoopGroup = nil
    }
    
    func setResponse(for path: String, response: MockResponse) {
        responses[path] = response
    }
    
    func getResponse(for path: String) -> MockResponse {
        return responses[path] ?? MockResponse(statusCode: .notFound, body: "404 Not Found")
    }
    
    func getURL() -> String {
        return "http://127.0.0.1:\(port)"
    }
}

private class HTTPServerHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private let mockServer: MockHTTPServer
    
    init(mockServer: MockHTTPServer) {
        self.mockServer = mockServer
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let request):
            let response = mockServer.getResponse(for: request.uri)
            
            var headers = response.headers
            headers.add(name: "Content-Length", value: String(response.body.utf8.count))
            headers.add(name: "Connection", value: "close")
            
            let responseHead = HTTPResponseHead(
                version: request.version,
                status: response.statusCode,
                headers: headers
            )
            
            context.write(wrapOutboundOut(.head(responseHead)), promise: nil)
            
            let body = response.body
            var buffer = context.channel.allocator.buffer(capacity: body.utf8.count)
            buffer.writeString(body)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            
            context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { _ in
                context.close(promise: nil)
            }
            
        case .body, .end:
            break
        }
    }
}