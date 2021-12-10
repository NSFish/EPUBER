//
//  File.swift
//  
//
//  Created by nsfish on 2021/7/4.
//

import Foundation

// https://stackoverflow.com/a/31443717/2135264
public enum Error: LocalizedError {
    case general(String)
}

public func numberStringByAddingZerosInto(_ numberString: String, tillReach count: Int) throws -> String {
    guard numberString.trimmingCharacters(in: .decimalDigits).count == 0 else {
        throw Error.general("非纯数字字符串无法使用本方法")
    }
    
    let length = count - numberString.count
    guard length > 0 else {
        return numberString
    }
    
    var numberString = numberString
    length.times {
        numberString = "0" + numberString
    }
    
    return numberString
}
