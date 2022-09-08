//
//  NetworkLoaderDelegate.swift
//  crawler
//
//  Created by Benjamin Rannow on 06.09.22.
//

import Foundation

protocol NetworkLoaderDelegate {
    func complete(loader: NetworkLoader, task: CrawlerTask, urls: Set<String>) -> Void
    func getBaseUrl(loader: NetworkLoader, task: CrawlerTask) -> URL
}
