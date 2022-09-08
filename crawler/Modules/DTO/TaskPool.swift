//
//  TaskPool.swift
//  crawler
//
//  Created by Benjamin Rannow on 07.09.22.
//

import Foundation

class TaskPool {
    
    var openTask: [UInt: CrawlerTask] = [:]
    var porcessTask: [UInt: CrawlerTask] = [:]
    var finishTask: [UInt: CrawlerTask] = [:]
    var blacklist: [UInt: CrawlerTask] = [:]
    var allTasks: [UInt: CrawlerTask] = [:]
    var urlList: [String] = []
    
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
        let uid: Int = Int(urlList.firstIndex(of: link) ?? -1)
        if (uid >= 0) {
            return UInt(uid)
        }
        
        let newUid = urlList.endIndex
        urlList.insert(link, at: newUid)
        
        return UInt(newUid);
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
        
        if (openTask[taskId] == nil && porcessTask[taskId] == nil && finishTask[taskId] == nil) {
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
            porcessTask[taskId] = task
        }
        
        return task
    }
    
    func finish(task: CrawlerTask) -> Void {
        
        let taskId = self.getId(forTask: task)
        if (porcessTask[taskId] != nil) {
            porcessTask[taskId] = nil
        }
        finishTask[taskId] = task
    }
    
    func processedCount() -> UInt {
        return UInt(porcessTask.count)
    }
}
