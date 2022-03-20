//
//  main.swift
//  EPUBER
//
//  Created by nsfish on 2021/11/14.
//

import Foundation
import PTSwift

enum Options: String {
    
    case dryRun = "dry-run"
}

var epubURLString = ""
var cssFileURLString = ""
var ignoredFileNamesString = ""
var dstFolderURLString = ""
var optionString = ""
for (index, argument) in CommandLine.arguments.enumerated() {
    if (argument == "-f") {
        epubURLString = CommandLine.arguments[index + 1]
    }
    else if (argument == "-style") {
        cssFileURLString = CommandLine.arguments[index + 1]
    }
    else if (argument == "-ignore") {
        ignoredFileNamesString = CommandLine.arguments[index + 1]
    }
    else if (argument == "-d") {
        dstFolderURLString = CommandLine.arguments[index + 1]
    }
    else if (argument == "-option") {
        optionString = CommandLine.arguments[index + 1]
    }
}

let cssFileURL = URL(fileURLWithPath: cssFileURLString)
if !FM.exist(at: cssFileURL, type: .file) {
    CLI.exit(with: "指定的文件 " + cssFileURLString + " 不存在")
}
else if cssFileURL.lowercasedExtension() != "css" {
    CLI.exit(with: "指定的文件 " + cssFileURLString + " 扩展名非法")
}

let epubURL = URL(fileURLWithPath: epubURLString)
if !FM.exist(at: epubURL) {
    CLI.exit(with: "输入非法: " + epubURLString + " 不存在")
}

var dstFolder: URL?
if dstFolderURLString.count > 0 {
    let folder = URL(fileURLWithPath: dstFolderURLString)
    
    if !FM.exist(at: folder, type: .folder) {
        CLI.exit(with: "输入非法: " + dstFolderURLString + " 不存在, 或者不是文件夹")
    }
    else {
        dstFolder = folder
    }
}

let ignoredFileNames = ignoredFileNamesString.components(separatedBy: ",")

var shouldZipUp = true
if let option = Options(rawValue: optionString),
   option == .dryRun {
    shouldZipUp = false
}

let structure = Structure(epubURL: epubURL,
                          cssFileURL: cssFileURL,
                          ignoredFileNames: ignoredFileNames)
structure.organize()

let text = Text(cssFilePosition: structure.cssFilePosition,
                chapterFileURLs: structure.chapterFileURLs)
text.polish()

let contentOPF = ContentOPF(url: structure.contentOPFURL,
                            tocNCXFileName: structure.tocNCXURL.lastPathComponent,
                            cssFileName: structure.cssFileURL.lastPathComponent,
                            coverFileName: structure.coverFileURL.lastPathComponent,
                            imageURLs: structure.imageURLs,
                            chapterFileURLs: structure.chapterFileURLs)
contentOPF.polish()

let tocNCX = TOCNCX(url: structure.tocNCXURL, volumes: text.volumes)
tocNCX.polish()

structure.generate(shouldZipUp: shouldZipUp, to: dstFolder)
