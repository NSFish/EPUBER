//
//  File.swift
//  
//
//  Created by nsfish on 2021/7/4.
//

import Foundation

// https://stackoverflow.com/a/30554255/2135264
extension Int {
    
    func times(_ f: () -> ()) {
        if self > 0 {
            for _ in 0..<self {
                f()
            }
        }
    }
    
    func times(_ f: @autoclosure () -> ()) {
        if self > 0 {
            for _ in 0..<self {
                f()
            }
        }
    }
}
