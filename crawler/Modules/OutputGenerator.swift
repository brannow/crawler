//
//  OutputGenerator.swift
//  crawler
//
//  Created by Benjamin Rannow on 07.09.22.
//

import Foundation

class OutputGenerator {
    
    public static func generateOutput(fromPool pool: TaskPool) -> String {
        
        var outputString: String = self.generateOutputLineHeader() + "\n"
        for task in pool.allTasks {
            let line = self.generateOutputLine(forTask: task.value, inPool: pool)
            outputString += String(line + "\n")
        }
        
        return outputString
    }
    
    private static func generateOutputLine(forTask task: CrawlerTask, inPool pool: TaskPool) -> String {
        
        var pids:[String] = []
        for pid in task.parentId {
            pids.append(String(pid))
        }
        let cc: CacheControl = CacheControl(headers: task.header);
        
        return String(pool.getId(forTask: task)) + " " + pids.joined(separator: ",") + " " + String(task.code) + " " + String(cc.cacheable) + " " + String(cc.maxAge) + " " + String(task.requestTime) + " " + task.url.absoluteString
    }
    
    private static func generateOutputLineHeader() -> String
    {
        return "ID Parent_Ids HTTP_CODE cacheable maxAge Request_Time_MS URL"
    }
}
