//
//  CommandArgumentParser.swift
//  crawler
//
//  Created by Benjamin Rannow on 06.09.22.
//

import Foundation


struct OptionType {
    
    enum Types {
        case withValue
        case withoutValue
    }
    
    let key: String
    let type: Types
    
    init(withKey key: String, hasValue typeCheck: Bool) {
        self.key = key
        self.type = typeCheck ? Types.withValue : Types.withoutValue
    }
    
    init(withKey key: String) {
        self.key = key
        self.type = Types.withoutValue
    }
}

class ArgumentParser {
    
    static func parse(arguments:[String], config: [OptionType]) -> CommandArgumentResult
    {
        return self.parseInternal(array: arguments, config: config)
    }
    
    static func getOption(key: String, config: [OptionType]) -> OptionType? {
        for item in config {
            if (key == item.key) {
                return item
            }
        }
        
        return nil
    }
    
    private static func parseInternal(array:[String], config: [OptionType]) -> CommandArgumentResult
    {
        var result = CommandArgumentResult();
        var optionValueList: [String] = [String]()
        
        
        var lastOption: OptionType? = nil
        for (index, element) in array.enumerated() {
            
            if (index == 0) {
                continue
            }
            
            if (element.hasPrefix("-")) {
                let option = getOption(key: element, config: config)
                if (option == nil) {
                    continue
                }
                
                result.options.append(Option(key: element))
                if (option?.type == OptionType.Types.withoutValue) {
                    lastOption = nil
                } else {
                    lastOption = option
                }
                
            } else if(lastOption != nil) {
                var optionIndex = -1
                for (index, subOption) in result.options.enumerated() {
                    if (subOption.key == lastOption?.key) {
                        optionIndex = index
                    }
                }
                if (optionIndex >= 0) {
                    result.options[optionIndex].value = element
                    optionValueList.append(element)
                }
                lastOption = nil
            }
            
            if (!element.hasPrefix("-")) {
                result.arguments.append(Argument(value: element))
            }
        }
        
        let search = result.arguments.enumerated();
        for (_, argument) in search {
            if (optionValueList.contains(argument.value)) {
                let currentIndex:Int = Int(result.arguments.firstIndex(where: {$0.value == argument.value}) ?? -1)
                if (currentIndex >= 0) {
                    result.arguments.remove(at: currentIndex)
                }
            }
        }
        
        return result
    }
}
/**

         foreach ($argv as $value) {
             if ($value[0] === '-') {
                 $result['o'][$value] = true;
                 $lastOption = $value;
             } elseif ($lastOption !== '') {
                 $result['o'][$lastOption] = $value;
                 $lastOption = '';
             }
         }

         $result['a'] = array_values(array_diff($result['a'], $result['o']));
         return $result;
 */
