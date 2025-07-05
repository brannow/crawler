//
//  TaskPool.swift
//  crawler
//
//  Created by Benjamin Rannow on 07.09.22.
//

import Foundation

class TaskPool {
    
    var openTask: [UInt: CrawlerTask] = [:]
    var processTask: [UInt: CrawlerTask] = [:]
    var finishTask: [UInt: CrawlerTask] = [:]
    var blacklist: [UInt: CrawlerTask] = [:]
    var allTasks: [UInt: CrawlerTask] = [:]
    var urlSet: Set<String> = Set<String>()
    var urlToIdMap: [String: UInt] = [:]
    private var nextId: UInt = 0
    
    func getId(forTask task: CrawlerTask) -> UInt {
        
        if (task.id != nil) {
            return task.id!;
        }
        
        let taskId: UInt = self.getId(forUrl: task.url)
        task.id = taskId
        return taskId;
    }
    
    private func getId(forString link:String) -> UInt
    {
        // Check if URL already exists
        if let existingId = urlToIdMap[link] {
            return existingId
        }
        
        // Create new ID for URL
        let newId = nextId
        nextId += 1
        urlSet.insert(link)
        urlToIdMap[link] = newId
        
        return newId
    }
    
    private func getId(forUrl url:URL) -> UInt
    {
        return getId(forString: url.absoluteString)
    }
    
    func createTask(withUrl url: URL) -> CrawlerTask {
        return createTask(
            withUrl: url,
            andUID: getId(forUrl: url)
        )
    }
    
    func createTask(withString link: String) -> CrawlerTask {
        return createTask(
            withUrl: URL(string: link)!,
            andUID: getId(forString: link)
        )
    }
    
    private func createTask(withUrl url: URL, andUID taskId: UInt) -> CrawlerTask
    {
        var task: CrawlerTask? = allTasks[taskId] ?? nil
        if (task == nil) {
            task = CrawlerTask(url: url)
            task!.id = taskId
            allTasks[taskId] = task
        }
        
        return task!
    }
    
    func addNew(task: CrawlerTask) -> UInt {
        
        let taskId = self.getId(forTask: task)
        
        if (openTask[taskId] == nil && processTask[taskId] == nil && finishTask[taskId] == nil) {
            openTask[taskId] = task
        }
        
        return taskId
    }
    
    func addNew(task: CrawlerTask, parentTask: CrawlerTask) -> UInt {
        
        let taskId = self.addNew(task: task)
        task.parentId.insert(
            self.getId(forTask: parentTask)
        )
        
        return taskId
    }
    
    func addNew(blacklistTask: CrawlerTask, parentTask: CrawlerTask) -> UInt {
        
        let taskId = self.getId(forTask: blacklistTask)
        
        if (blacklist[taskId] == nil) {
            blacklist[taskId] = blacklistTask
        }
        
        blacklistTask.parentId.insert(
            self.getId(forTask: parentTask)
        )
        
        return taskId
    }
    
    func processOpenTask() -> CrawlerTask? {
    
        let task = openTask.popFirst()?.value
        if (task != nil) {
            let taskId = self.getId(forTask: task!)
            processTask[taskId] = task
        }
        
        return task
    }
    
    func finish(task: CrawlerTask) -> Void {
        
        let taskId = self.getId(forTask: task)
        if (processTask[taskId] != nil) {
            processTask[taskId] = nil
        }
        finishTask[taskId] = task
    }
    
    func processedCount() -> UInt {
        return UInt(processTask.count)
    }
}
