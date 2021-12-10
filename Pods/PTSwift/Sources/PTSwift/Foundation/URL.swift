//
//  File.swift
//  
//
//  Created by nsfish on 2021/7/4.
//

import Foundation

public extension URL {
    
    func replacingLastPathComponent(with newName: String) -> URL {
        return deletingLastPathComponent().appendingPathComponent(newName)
    }
    
    // TODO: Cannot use mutating member on immutable value: 'self' is immutable
//    func replaceLastPathComponent(with newName: String) {
//        deleteLastPathComponent()
//        appendPathComponent(newName)
//    }
}
