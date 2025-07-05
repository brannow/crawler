//
//  NetworkLoader.swift
//  crawler
//
//  Created by Benjamin Rannow on 06.09.22.
//

import Foundation
import SwiftyRequest
import NIOHTTP1
import NIO

class NetworkLoader
{
    var delegate: NetworkLoaderDelegate?
    var eventLoopGroup: MultiThreadedEventLoopGroup?
    
    // Shared EventLoopGroup for all network operations - use system core count or default to 4
    private static let sharedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: ProcessInfo.processInfo.processorCount > 0 ? ProcessInfo.processInfo.processorCount : 4)
    
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
        // Use shared EventLoopGroup to prevent memory leaks
        let request = RestRequest(
            method: HTTPMethod.get,
            url: crawlerTask.url.absoluteString,
            insecure: true,
            eventLoopGroup: NetworkLoader.sharedEventLoopGroup
        )
        request.headerParameters.removeAll()
        request.acceptType = "*/*"
        request.productInfo = "BR-Crawler: 1.0 / site-crawler"
        request.contentType = nil
        let start = DispatchTime.now()
        request.responseString { result in
            switch result {
            case .success(let response):
                let nanoTime = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
                let timeInterval = Double(nanoTime) / 1_000_000
                self.complete(task: crawlerTask, html: response.body, headers: response.headers, code: response.status.code, requestTimeMS: timeInterval)
            case .failure(let error):
                
                let nanoTime = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
                let timeInterval = Double(nanoTime) / 1_000_000
                
                let response = error.response
                if (response != nil) {
                    self.complete(task: crawlerTask, html: "", headers: response!.headers, code: response!.status.code, requestTimeMS: timeInterval)
                } else {
                    self.complete(task: crawlerTask, html: "", headers: HTTPHeaders(), code: 500, requestTimeMS: timeInterval)
                }
            }
        }
    }

    
    func complete(task: CrawlerTask, html: String, headers: HTTPHeaders, code: UInt, requestTimeMS: Double) -> Void
    {
        if (self.delegate != nil) {
            let newUrls = HTMLLinkParser.parse(html: html, baseUrl: (self.delegate?.getBaseUrl(loader: self, task: task))!)
            DispatchQueue.main.async {
                
                task.code = code
                task.header = headers
                task.requestTime = requestTimeMS
                
                // No need to shutdown shared EventLoopGroup
                self.delegate!.complete(loader: self, task: task, urls: newUrls)
            }
        }
    }
}
