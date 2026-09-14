//
//  Crawler.swift
//  crawler
//
//  Created by Benjamin Rannow on 05.09.22.
//

import Foundation

extension DispatchQueue {
    static func background(delay: Double = 0.0, background: (()->Void)? = nil, completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            background?()
            if let completion = completion {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: {
                    completion()
                })
            }
        }
    }
}

class Crawler: NetworkLoaderDelegate
{
    let numOfThreads: UInt
    var baseUrl: URL?
    var pool: TaskPool
    let verbose: Bool
    let filterList: [String]
    let keywordsList: [String]
    let limit: UInt
    let maxAttempts: UInt
    var fileLocation: URL? = nil

    /// Routes every process-ending path instead of calling exit() directly.
    /// Production leaves this as real exit() -- CLI behavior is unchanged.
    /// Since crawler.swift's sources are compiled directly into the test bundle
    /// (no separate host process), a bare exit() here would kill the whole
    /// XCTest run, not just the current test; tests override this with a
    /// no-op that just records the code.
    var exitHandler: (Int32) -> Void = { code in exit(code) }

    /// Guards the two warmupThreads() completion branches below. execute()
    /// schedules a warmupThreads() call for every dispatched task regardless of
    /// that task's own completion, so several stale calls can still be queued
    /// up when the pool empties out; each would otherwise re-run generateOutput()
    /// and call exitHandler(0) again. Production never noticed because the
    /// first exit(0) killed the process before a second call was possible.
    private var hasFinished = false

    private func finish(withCode code: Int32) {
        guard !hasFinished else { return }
        hasFinished = true
        generateOutput()
        exitHandler(code)
    }

    init(withThreads: UInt = 1, filter: String, keywords: String, limit: UInt = 0, verbose: Bool, outputFileLocation: String = "", maxAttempts: UInt = 3)
    {
        self.maxAttempts = maxAttempts < 1 ? 1 : maxAttempts
        self.pool = TaskPool()
        self.verbose = verbose
        numOfThreads = withThreads;
        self.limit = limit
        
        if (outputFileLocation != "") {
            let absoluteFileUrl = NSString(string: outputFileLocation).expandingTildeInPath
            let currentDir = URL(string: FileManager.default.currentDirectoryPath);
            self.fileLocation = URL(fileURLWithPath: absoluteFileUrl, relativeTo: currentDir)
        }
        
        let removeCharacters: Set<Character> = [" "]
        var mutateFilter = filter
        mutateFilter.removeAll(where: { removeCharacters.contains($0) } )
        filterList = mutateFilter.components(separatedBy: ",")
        
        // Process keywords similar to filter, but handle escaped commas
        var mutateKeywords = keywords
        mutateKeywords.removeAll(where: { removeCharacters.contains($0) } )
        keywordsList = mutateKeywords.components(separatedBy: ",").filter { !$0.isEmpty }
    }
    
    func createEmptyOutputFile() -> Void {
        if (self.fileLocation != nil) {
            do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: self.fileLocation!.path) {
                    try fileManager.removeItem(atPath: self.fileLocation!.path)
                }
                try "".write(to: self.fileLocation!, atomically: true, encoding: .utf8)
            } catch {
                print("Could not create output file at location: \(self.fileLocation!.absoluteString)")
                exitHandler(1)
                return
            }
        }
    }

    func crawl(from urlString: String) -> Void
    {
        self.createEmptyOutputFile()
        guard let url = URL(string: urlString) else {
            print("invalid url: \(urlString) - exit")
            exitHandler(1)
            return
        }
        guard let host = url.host, let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            print("invalid url: '\(urlString)' - exit")
            exitHandler(1)
            return
        }
        self.baseUrl = URL(string: scheme + "://" + host)!
        
        _ = self.pool.addNew(
            task: self.pool.createTask(withUrl: url)
        )
        warmupThreads()
    }
    
    func generateOutput() -> Void {
        if (self.fileLocation != nil) {
            print("Generate Output at: " + self.fileLocation!.absoluteString)
            do {
                let fileHandle = try FileHandle(forWritingTo: self.fileLocation!)
                let output = OutputGenerator.generateOutput(fromPool: self.pool)
                fileHandle.write(output.data(using: .utf8)!)
                fileHandle.closeFile()
            } catch {
                print("Error writing to file \(error)")
            }
            
        }
    }
    
    
    func warmupThreads() -> Void {
        
        if ((self.pool.openTask.count + self.pool.processTask.count) == 0) {
            finish(withCode: 0)
            return
        }

        if (self.limit > 0) {
            let limitTaskCount = self.pool.processTask.count + self.pool.finishTask.count
            if (limitTaskCount >= self.limit) {

                if (self.pool.processTask.count == 0) {
                    finish(withCode: 0)
                    return
                }

                return
            }
        }
        
        let processedCount = pool.processedCount()
        if (processedCount >= self.numOfThreads) {
            return
        }
        
        // Half-open range on purpose. This was `processedCount...self.numOfThreads`,
        // a CLOSED range, which starts one MORE request than asked for -- `-t 4`
        // ran 5 in flight and `-limit 250` fetched 251.
        for _ in processedCount..<self.numOfThreads {
            if (execute() == false) {
                break;
            }
        }
    }
    
    func execute() -> Bool {
        
        let task = self.pool.processOpenTask();
        if (task == nil) {
            return false
        }
        
        DispatchQueue.background(delay: 0.1, background: {
            self.process(task: task!)
        }, completion: {
            self.warmupThreads()
        })
        
        return true
    }
    
    // runs in sub thread
    func process(task: CrawlerTask) -> Void
    {
        let loader = NetworkLoader();
        loader.setDelegate(delegate: self)
        loader.maxAttempts = self.maxAttempts
        loader.load(withTask: task)
    }
    
    func complete(loader: NetworkLoader, task: CrawlerTask, urls: Set<String>, html: String) -> Void
    {
        // Search for keywords in HTML content
        task.matchedKeywords = findKeywordsInHtml(html: html)
        
        for link in urls {
            let url: URL? = URL(string: link)
            if (url == nil) {
                continue
            }
            
            let newTask = pool.createTask(withUrl: url!)
            if (!isBlacklisted(url: newTask.url)) {
                _ = pool.addNew(task: newTask, parentTask: task)
            } else {
                _ = pool.addNew(blacklistTask: newTask, parentTask: task)
            }
        }
        
        pool.finish(task: task)
        printTask(task: task)
        self.warmupThreads()
    }
    
    func isBlacklisted(url: URL) -> Bool {
        
        for filterString in filterList {
            if (url.absoluteString.contains(filterString)) {
                return true
            }
        }
        
        return false
    }
    
    func findKeywordsInHtml(html: String) -> [String] {
        var foundKeywords: [String] = []
        
        if keywordsList.isEmpty {
            return foundKeywords
        }
        
        let lowercaseHtml = html.lowercased()
        
        for keyword in keywordsList {
            let lowercaseKeyword = keyword.lowercased()
            if lowercaseHtml.contains(lowercaseKeyword) {
                foundKeywords.append(keyword)
            }
        }
        
        return foundKeywords
    }
    
    func printTask(task: CrawlerTask) -> Void {
        
        if (self.verbose == true) {
            
            let numOfTasks: String = "(o:\(self.pool.openTask.count)|f:\(self.pool.finishTask.count)|b:\(self.pool.blacklist.count)|a:\(self.pool.allTasks.count))"
            let date = Date()
            let format = DateFormatter()
            format.dateFormat = "[HH:mm:ss]"
            let timestamp = format.string(from: date)
            
            // A transport failure has no status code -- say so, rather than
            // printing a 0 that reads like "not fetched".
            let status: String = task.transportError != nil ? "ERR" : String(task.code)
            let time: String = String(task.requestTime) + "ms"
            
            let cc: CacheControl = CacheControl(headers: task.header);
            
            let keywordsOutput = task.matchedKeywords.isEmpty ? "" : " [" + task.matchedKeywords.joined(separator: ",") + "]"
            var errorOutput = ""
            if let reason = task.transportError {
                errorOutput = " <" + reason + (task.attempts > 1 ? " after \(task.attempts) attempts" : "") + ">"
            } else if task.attempts > 1 {
                errorOutput = " <recovered after \(task.attempts) attempts>"
            }
            // Console output isn't a positional format (variable-width timestamp,
            // optional trailing tags already), so fields are ordered for
            // readability -- unlike the report file, there's no compatibility
            // reason to keep this order fixed.
            let output = timestamp + " " + numOfTasks + " " + status + " " + cc.raw + " " + String(cc.maxAge) + " " + cc.expires + " " + String(task.bytes) + "b " + time + " " + String(task.url.absoluteString) + keywordsOutput + errorOutput
            
            print(output);
        }
    }
    
    func getBaseUrl(loader: NetworkLoader, task: CrawlerTask) -> URL
    {
        return self.baseUrl!
    }
}
