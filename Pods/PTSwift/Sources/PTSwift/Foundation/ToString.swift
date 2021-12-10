//
//  File.swift
//  
//
//  Created by nsfish on 2021/7/4.
//

import Foundation

public extension LosslessStringConvertible {
    
    func toString() -> String {
        return String.init(self)
    }
}

// 比如说 var currentCNDigit = storedTempDigit.reversed().toString()
public extension ReversedCollection where Element == Character {
    
    func toString() -> String {
        return String(self)
    }
}

public extension Array where Element == String {
    
    func toString() -> String {
        return String(self.description)
    }
}
