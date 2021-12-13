//
//  main.swift
//  EPUBER
//
//  Created by nsfish on 2021/11/14.
//

import Foundation
import PTSwift

var epubURLString = ""
var cssFileURLString = ""
var uselessFileNamesString = ""
for (index, argument) in CommandLine.arguments.enumerated() {
    if (argument == "-f") {
        epubURLString = CommandLine.arguments[index + 1]
    }
    else if (argument == "-c") {
        cssFileURLString = CommandLine.arguments[index + 1]
    }
    else if (argument == "-u") {
        uselessFileNamesString = CommandLine.arguments[index + 1]
    }
}

let cssFileURL = URL(fileURLWithPath: cssFileURLString)
let epubURL = URL(fileURLWithPath: epubURLString)

let uselessFileNames = uselessFileNamesString.components(separatedBy: ",")
let structure = Structure.init(epubURL: epubURL, cssFileURL: cssFileURL, uselessFileNames: uselessFileNames)
structure.organize()

let text = Text.init(cssFilePosition: structure.cssFilePosition,
                     chapterFileURLs: structure.chapterFileURLs)
text.polish()

let contentOPF = ContentOPF.init(url: structure.contentOPFURL,
                                 tocNCXFileName: structure.tocNCXURL.lastPathComponent,
                                 cssFileName: structure.cssFileURL.lastPathComponent,
                                 coverFileName: structure.coverFileURL.lastPathComponent,
                                 imageURLs: structure.imageURLs,
                                 chapterFileURLs: structure.chapterFileURLs)
contentOPF.polish()

let tocNCX = TOCNCX.init(url: structure.tocNCXURL,
                         volumns: text.volumns)
tocNCX.polish()

structure.generate()
