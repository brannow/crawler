//
//  CommandArgumentResult.swift
//  crawler
//
//  Created by Benjamin Rannow on 06.09.22.
//

import Foundation

struct Argument {
    var value: String
    
    init(value: String) {
        self.value = value
    }
}

struct Option {
    var key: String
    var value: String?
    
    init(key: String, value: String?) {
        self.key = key
        self.value = value
    }
    init(key: String) {
        self.key = key
        self.value = nil
    }
}

struct CommandArguemntResult {
    var options:[Option] = [Option]()
    var arguments:[Argument] = [Argument]()
    
    func hasOption(key: String) -> Bool {
        return self.getOptionValue(key: key).exist
    }
    
    func getOptionValue(key: String, defaultValue: String = "") -> (exist: Bool, value: String?) {
        for option in options {
            if (option.key == key) {
                return (true, option.value)
            }
        }
        
        return (false, defaultValue)
    }
}
