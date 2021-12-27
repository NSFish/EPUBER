//
//  Utils.swift
//  EPUBER
//
//  Created by nsfish on 2021/11/15.
//

import Foundation
import PTSwift

func decompress(fileURL: URL, into folder: URL) {
    let task = Process()
    task.currentDirectoryURL = folder
    task.executableURL = URL(fileURLWithPath: "/Users/nsfish/Documents/Github/PersonalScripts/unar")
    // unar
    // -force-directory (-d)                   Always create a containing directory for the contents of the unpacked archive. By default, a directory is created if there is more than one top-level file or folder.
    // 即使解压出来的内容只有一个文件，也创建文件夹
    task.arguments = [fileURL.path, "-d"]
    
    let outputPipe = Pipe()
    task.standardOutput = outputPipe
    
    task.launch()
    
    task.waitUntilExit()
}

func zip(_ items: [URL], fileName: String, into folder: URL) {
    let tempFolder = folder.appendingPathComponent("zipping_temp" + Date().timeStamp())
    FM.createFolder(at: tempFolder)
    FM.copy(items: items, toFolder: tempFolder)
        
    // https://superuser.com/a/119661
    let task = Process()
    task.currentDirectoryURL = tempFolder
    task.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    task.arguments = ["-r", fileName, ".", "-x", "*.DS_Store*"]
    
//    let outputPipe = Pipe()
//    task.standardOutput = outputPipe
    
    task.launch()
    task.waitUntilExit()
    
    let destURL = folder.appendingPathComponent(fileName)
    if FM.itemExist(atURL: destURL, type: .file) {
        try! FM.removeItem(at: destURL)
    }
    try! FM.moveItem(at: tempFolder.appendingPathComponent(fileName), to: destURL)
    try! FM.removeItem(at: tempFolder)
}
