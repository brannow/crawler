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
        let keywords = task.matchedKeywords.joined(separator: ",")
        
        // Keywords may be empty, so every column after it needs a placeholder --
        // otherwise the field count varies per row and the output stops being
        // parseable by column index.
        let keywordsField = keywords.isEmpty ? "-" : keywords
        let errorField = task.transportError ?? "-"
        // The seed URL has no parents, so this field was EMPTY for it and every
        // column after shifted left by one -- the row could not be read by index.
        let parentField = pids.isEmpty ? "-" : pids.joined(separator: ",")

        return String(pool.getId(forTask: task)) + " " + parentField + " " + String(task.code) + " " + String(cc.cacheable) + " " + String(cc.maxAge) + " " + String(task.requestTime) + " " + task.url.absoluteString + " " + keywordsField + " " + String(task.attempts) + " " + errorField
    }
    
    private static func generateOutputLineHeader() -> String
    {
        // HTTP_CODE is now ONLY ever a status a server actually sent. A transport
        // failure (refused, TLS handshake, timeout) leaves it 0 and names the
        // cause in Error -- it is no longer reported as a fabricated 500.
        return "ID Parent_Ids HTTP_CODE cacheable maxAge Request_Time_MS URL Keywords Attempts Error"
    }
}
