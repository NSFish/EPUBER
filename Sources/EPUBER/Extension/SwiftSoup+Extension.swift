//
//  File.swift
//  
//
//  Created by NSFish on 2022/3/13.
//

import Foundation
import SwiftSoup

extension Element {
    
    func removeAllChildren() throws {
        try getChildNodes().forEach { try removeChild($0) }
    }
    
    func removeAllAttributes() throws {
        try getAttributes()?.forEach { try removeAttr($0.getKey()) }
    }
}
