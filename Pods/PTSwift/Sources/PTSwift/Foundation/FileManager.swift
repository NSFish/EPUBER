//
//  File.swift
//  
//
//  Created by nsfish on 2021/7/1.
//

import Foundation

public let FM = FileManager.default

public extension FileManager {
    
    func subFoldersIn(folder: URL, sortedByName: Bool = true) -> [URL] {
        var subFolders = try! FM.contentsOfDirectory(at: folder,
                                                     includingPropertiesForKeys: nil,
                                                     options: [.skipsHiddenFiles, .skipsPackageDescendants])
            .filter { $0.hasDirectoryPath }
        
        if sortedByName {
            subFolders.sort { $0.lastPathComponent < $1.lastPathComponent }
        }
        
        return subFolders
    }
    
    func filesIn(folder: URL, sortedByName: Bool = true) -> [URL] {
        var subFiles = try! FM.contentsOfDirectory(at: folder,
                                                   includingPropertiesForKeys: nil,
                                                   options: [.skipsHiddenFiles, .skipsPackageDescendants])
            .filter { !$0.hasDirectoryPath }
        
        if sortedByName {
            subFiles.sort { $0.lastPathComponent < $1.lastPathComponent }
        }
        
        return subFiles
    }
}
