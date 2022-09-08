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
    
    func setDelegate(delegate: NetworkLoaderDelegate?) {
        self.delegate = delegate
    }
    
    func load(withTask crawlerTask: CrawlerTask) -> Void
    {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let request = RestRequest(
            method: HTTPMethod.get,
            url: crawlerTask.url.absoluteString,
            insecure: true,
            eventLoopGroup: eventLoopGroup
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
                
                try? self.eventLoopGroup!.syncShutdownGracefully()
                self.delegate!.complete(loader: self, task: task, urls: newUrls)
            }
        }
    }
}
