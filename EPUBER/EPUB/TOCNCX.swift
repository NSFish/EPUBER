//
//  NCX.swift
//  EPUBER
//
//  Created by nsfish on 2021/11/18.
//

import Foundation
import SwiftyXML
import AppKit

class NavPoint {
    
    let id: String
    let playOrder: Int
    let navLabelText: String
    let contentSrc: String
    var subPoints = [NavPoint]()
    
    init(id: String, playOrder: Int, navLabelText: String, contentSrc: String) {
        self.id = id
        self.playOrder = playOrder
        self.navLabelText = navLabelText
        self.contentSrc = contentSrc
    }
    
    func toXML() -> XML {
        let navPoint = XML(name: "navPoint", attributes: ["id": id, "playOrder": String(playOrder)])
        navPoint.attributesOrder = ["id", "playOrder"]
        
        let navLabel = XML(name: "navLabel")
        navLabel.childrenAtTheSameLine = true
        navPoint.addChild(navLabel)
        
        let text = XML(name: "text", value: navLabelText)
        text.childrenAtTheSameLine = true
        navLabel.addChild(text)
        
        let content = XML(name: "content", attributes: ["src": contentSrc])
        navPoint.addChild(content)
        
        subPoints.forEach { subPoint in
            navPoint.addChild(subPoint.toXML())
        }
        
        return navPoint
    }
}

class TOCNCX {
    
    let url: URL
    let volumns: [Volumn]
    
    init(url: URL, volumns: [Volumn]) {
        self.url = url
        self.volumns = volumns
    }
    
    func polish() {
        let tocNCX = XML(url: url)!
        let newTOCNCX = copyXMLWithoutChildren(original: tocNCX)
        
        newTOCNCX.attributesOrder = ["version", "xmlns", "xml:lang"]
        
        let head = tocNCX.head.tryGetXML()
        head.addEmptyLineAtBottom = true
        head.children.forEach { meta in
            meta.attributesOrder = ["name", "content"]
        }
        newTOCNCX.addChild(head)
        
        let docTitle = tocNCX.docTitle.tryGetXML()
        docTitle.addEmptyLineAtBottom = true
        newTOCNCX.addChild(docTitle)
        
        let newNavMap = copyXMLWithoutChildren(original: tocNCX.navMap.tryGetXML())
        newTOCNCX.addChild(newNavMap)
        addNavPoints(to: newNavMap)
        
        var result = """
        <?xml version="1.0" encoding="utf-8" standalone="no"?>
        <!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">
        """
        result += "\n" + newTOCNCX.toXMLString()
        try! result.write(to: url, atomically: false, encoding: .utf8)
    }
}

extension TOCNCX {
    
    func addNavPoints(to navMap: XML) {
        // 只有一卷，也就是不分卷，直接添加章节名即可
        var playOrder = 0
        if volumns.count == 1 {
            volumns.first!.chapters.forEach { chapter in
                let chapterPoint = navPoint(from: chapter, playOrder: &playOrder)
                navMap.addChild(chapterPoint.toXML())
            }
            
            return
        }
        
        // 如果有多卷，则分层处理，但 playOrder 是连续的
        volumns.forEach { volumn in
            let volumnPoint = NavPoint(id: "volumn_" + volumn.fileURL!.nameWithoutExtension(),
                                            playOrder: calculate(&playOrder),
                                            navLabelText: volumn.title,
                                            contentSrc: "Text/" + volumn.fileURL!.lastPathComponent)
            
            volumn.chapters.forEach { chapter in
                let chapterPoint = navPoint(from: chapter, playOrder: &playOrder)
                volumnPoint.subPoints.append(chapterPoint)
            }
            
            navMap.addChild(volumnPoint.toXML())
        }
    }
    
    func navPoint(from chapter: Chapter, playOrder: inout Int) -> NavPoint {
        return NavPoint(id: "chapter_" + chapter.fileURL.nameWithoutExtension(),
                             playOrder: calculate(&playOrder),
                             navLabelText: chapter.title,
                             contentSrc: "Text/" + chapter.fileURL.lastPathComponent)
    }
    
    func calculate(_ playOrder: inout Int) -> Int {
        playOrder += 1
        return playOrder
    }
}
