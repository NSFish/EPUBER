//
//  File.swift
//  
//
//  Created by nsfish on 2021/7/4.
//

import Foundation

public extension String {
    
    /// 去除字符串中所有的指定 CharacterSet
    ///
    /// 相比之下, trimmingCharacters(in: .whitespacesAndNewlines) 只处理字符串左右两侧
    func removingCharacters(in set: CharacterSet) -> String {
        return components(separatedBy: set).joined()
    }
}
