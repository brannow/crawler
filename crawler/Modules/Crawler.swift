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
    let limit: UInt
    var fileLocation: URL? = nil
    
    init(withThreads: UInt = 1, filter: String, limit: UInt = 0, verbose: Bool, outputFileLocation: String = "")
    {
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
                exit(1)
            }
        }
    }
    
    func crawl(from urlString: String) -> Void
    {
        self.createEmptyOutputFile()
        guard let url = URL(string: urlString) else {
            print("invalid url: \(urlString) - exit")
            exit(1);
        }
        if ((url.host == nil || url.scheme == nil)) {
            print("invalid url: '\(urlString)' - exit")
            exit(1);
        }
        let scheme = url.absoluteString.starts(with: "http:") ? "http" : "https"
        self.baseUrl = URL(string: scheme + "://" + url.host!)!
        
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
            generateOutput()
            exit(0)
        }
        
        if (self.limit > 0) {
            let limitTaskCount = self.pool.processTask.count + self.pool.finishTask.count
            if (limitTaskCount >= self.limit) {
                
                if (self.pool.processTask.count == 0) {
                    generateOutput()
                    exit(0)
                }
                
                return
            }
        }
        
        let processedCount = pool.processedCount()
        if (processedCount >= self.numOfThreads) {
            return
        }
        
        for _ in processedCount...self.numOfThreads {
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
        loader.load(withTask: task)
    }
    
    func complete(loader: NetworkLoader, task: CrawlerTask, urls: Set<String>) -> Void
    {
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
    
    func printTask(task: CrawlerTask) -> Void {
        
        if (self.verbose == true) {
            
            let numOfTasks: String = "(o:\(self.pool.openTask.count)|f:\(self.pool.finishTask.count)|b:\(self.pool.blacklist.count)|a:\(self.pool.allTasks.count))"
            let date = Date()
            let format = DateFormatter()
            format.dateFormat = "[HH:mm:ss]"
            let timestamp = format.string(from: date)
            
            let status: String = String(task.code)
            let time: String = String(task.requestTime) + "ms"
            
            let cc: CacheControl = CacheControl(headers: task.header);
            
            let output = timestamp + " " + numOfTasks + " " + status + " " + String(cc.cacheable) + " " + String(cc.maxAge) + " " + time + " " + String(task.url.absoluteString)
            
            print(output);
        }
    }
    
    func getBaseUrl(loader: NetworkLoader, task: CrawlerTask) -> URL
    {
        return self.baseUrl!
    }
}
