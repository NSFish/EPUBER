//
//  Structure.swift
//  EPUBER
//
//  Created by nsfish on 2021/11/20.
//

import Foundation
import PTSwift

class Structure {
    
    private let epubURL: URL
    let cssFileURL: URL
    let ignoredFileNames: [String]
    
    let cssFilePosition = "../style.css"
    let epubNameWithoutExtension: String
    private var tempFolderURL: URL!
    private var tempEpubFolderURL: URL!
    
    private var epubFolderURL: URL!
    private(set) var OEBPSFolderURL: URL!
    private(set) var contentOPFURL: URL!
    private(set) var tocNCXURL: URL!
    private(set) var imageURLs = [URL]()
    private(set) var coverFileURL: URL!
    private(set) var chapterFileURLs = [URL]()
    
    init(epubURL: URL, cssFileURL: URL, ignoredFileNames: [String]) {
        self.epubURL = epubURL
        self.cssFileURL = cssFileURL
        self.ignoredFileNames = ignoredFileNames
        self.epubNameWithoutExtension = epubURL.nameWithoutExtension()
    }
    
    func organize() {
        let tempFolders = FM.contentsIn(folder: epubURL.deletingLastPathComponent()).filter { $0.nameWithoutExtension().hasPrefix("temp_") }
        FM.remove(items: tempFolders)
        
        tempFolderURL = epubURL.deletingLastPathComponent().appendingPathComponent("temp_" + Date().timeStamp())
        FM.createFolder(at: tempFolderURL)
        
        epubFolderURL = tempFolderURL.appendingPathComponent(epubNameWithoutExtension)
        // 如果传入的是 .epub 文件，则将 epub 文件解压到临时文件夹中
        if epubURL.pathExtension.lowercased() == "epub" {
            decompress(fileURL: epubURL, into: tempFolderURL)
        }
        else { // 如果传入的直接就是一个文件夹，则
            try! FM.copyItem(at: epubURL, to: epubFolderURL)
        }
        
        createTempEpubFolder(in: tempFolderURL)
    }
    
    func generate(shouldZipUp: Bool = true, to folder: URL? = nil) {
        let dstFolder = folder ?? epubURL.deletingLastPathComponent()
        let newFileName = "new_" + epubNameWithoutExtension
        
        if shouldZipUp {
            let contents = FM.contentsIn(folder: tempEpubFolderURL)
            zip(contents, fileName: newFileName + ".epub", into: dstFolder)
        }
        else {
            let dstURL = dstFolder.appendingPathComponent(newFileName)
            if FM.exist(at: dstURL) {
                try! FM.removeItem(at: dstURL)
            }
            try! FM.copyItem(at: tempEpubFolderURL, to: dstURL)
        }
        
        try! FM.removeItem(at: tempFolderURL)
    }
}

private extension Structure {
    
    func createTempEpubFolder(in tempFolder: URL) {
        // 在解压出来的文件夹边上构造一个新的文件夹结构
        tempEpubFolderURL = tempFolder.appendingPathComponent("temp_" + epubNameWithoutExtension)
        FM.createFolder(at: tempEpubFolderURL)
        
        // 构造 META-INF 和 mimetype
        let METAINFFolderURL = tempEpubFolderURL.appendingPathComponent("META-INF")
        FM.createFolder(at: METAINFFolderURL)
        let containerXML = """
        <?xml version='1.0' encoding='UTF-8'?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        
        let containerXMLURL = METAINFFolderURL.appendingPathComponent("container.xml")
        try! containerXML.write(to: containerXMLURL, atomically: false, encoding: .utf8)
        
        let mimetype = "application/epub+zip"
        let mimetypeURL = tempEpubFolderURL.appendingPathComponent("mimetype")
        try! mimetype.write(to: mimetypeURL, atomically: false, encoding: .utf8)
        
        // 构造 OEBPS 文件夹，并将需要的文件复制进来
        let contents = try! FM.nestedFilesIn(folder: epubFolderURL, level: 3)
            .filter { !ignoredFileNames.contains($0.lastPathComponent) }
        
        OEBPSFolderURL = tempEpubFolderURL.appendingPathComponent("OEBPS")
        FM.createFolder(at: OEBPSFolderURL)
        
        // css
        FM.copyItem(at: cssFileURL, toFolder: OEBPSFolderURL)
        
        // content.opf、toc.ncx
        guard let contentOPFURL = contents.filter({ $0.pathExtension.lowercased() == "opf" }).first else {
            return
        }
        self.contentOPFURL = FM.copyItem(at: contentOPFURL, toFolder: OEBPSFolderURL)
        
        guard let tocNCXURL = contents.filter({ $0.pathExtension.lowercased() == "ncx" }).first else {
            return
        }
        self.tocNCXURL = FM.copyItem(at: tocNCXURL, toFolder: OEBPSFolderURL)
        
        // 图片单独存入 Image/ 中
        let imageFolder = OEBPSFolderURL.appendingPathComponent("Image")
        FM.createFolder(at: imageFolder)
        
        let imageURLs = contents.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "jpeg" }
        self.imageURLs = imageURLs.filter { !$0.nameWithoutExtension().lowercased().contains("cover") }
        self.imageURLs = FM.copy(items: self.imageURLs, toFolder: imageFolder)
        
        // 封面不放入 Image/ 中
        guard let coverJPGURL = imageURLs.filter({ $0.nameWithoutExtension().lowercased().contains("cover") }).first else {
            return
        }
        self.coverFileURL = FM.copyItem(at: coverJPGURL, toFolder: OEBPSFolderURL)
        
        // 章节文件单独存入 Text/ 中
        let textFolder = OEBPSFolderURL.appendingPathComponent("Text")
        FM.createFolder(at: textFolder)
        
        // 章节文件扩展名可能是 .html 或 .xhtml，所以这里用 contains
        let chapters = contents.filter( { $0.pathExtension.lowercased().contains("html") })
            .sorted(by: { lhs, rhs in
                var set = CharacterSet()
                set.formUnion(.decimalDigits)
                set.insert(charactersIn: ".")
                set.invert()
                let left = lhs.nameWithoutExtension().removingCharacters(in: set).toDouble()!
                let right = rhs.nameWithoutExtension().removingCharacters(in: set).toDouble()!
                
                return left < right
            })
        
        let digits = String(chapters.count).count
        for (index, chapterURL) in chapters.enumerated() {
            let newName = String(index + 1).fillInZeroUntil(meet: digits) + ".html"
            let destURL = textFolder.appendingPathComponent(newName)
            try! FM.copyItem(at: chapterURL, to: destURL)
            
            self.chapterFileURLs.append(destURL)
        }
    }
}
