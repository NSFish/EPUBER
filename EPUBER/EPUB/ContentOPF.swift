//
//  OPFContent.swift
//  EPUBER
//
//  Created by nsfish on 2021/11/17.
//

import Foundation
import SwiftyXML

class ManifestItem {
    
    var id: String
    var href: String
    var mediaType: String
    
    init(id: String, href: String, mediaType: String) {
        self.id = id
        self.href = href
        self.mediaType = mediaType
    }
    
    func toXML() -> XML {
        let xml = XML.init(name: "item", attributes: ["id": id, "href": href, "media-type": mediaType], value: nil)
        xml.attributesOrder = ["id", "href", "media-type"]
        
        return xml
    }
}

class SpineItemRef {
    
    var idref: String
    var linear: String
    
    init(idref: String, linear: String) {
        self.idref = idref
        self.linear = linear
    }
    
    func toXML() -> XML {
        let xml = XML.init(name: "itemref", attributes: ["idref": idref, "linear": linear], value: nil)
        xml.attributesOrder = ["idref", "linear"]
        
        return xml
    }
}

class ContentOPF {
    
    let url: URL
    let tocNCXFileName: String
    let cssFileName: String
    let coverFileName: String
    let imageURLs: [URL]
    let chapterFileURLs: [URL]
    
    private var xml: XML
    
    init(url: URL, tocNCXFileName: String, cssFileName: String, coverFileName: String, imageURLs: [URL], chapterFileURLs: [URL]) {
        self.url = url
        self.tocNCXFileName = tocNCXFileName
        self.cssFileName = cssFileName
        self.coverFileName = coverFileName
        self.imageURLs = imageURLs
        self.chapterFileURLs = chapterFileURLs
        
        xml = XML.init(url: url)!
    }
    
    func polish() {
        let newXML = copyXMLWithoutChildren(original: xml)
        let metadata = xml.metadata.tryGetXML()
        let metas = metadata.children.filter { $0.name == "meta" }
        metas.forEach { meta in
            meta.attributesOrder = ["name", "content"]
            
            // .opf 文件中确保封面正确显示有三个地方要注意
            // 1. <head><meta name="cover" content="cover-image"></head>
            // 2. <manifest><item id="cover-image" href="cover.jpg" media-type="image/jpeg"/></manifest>
            // 3. <spine toc="ncxtoc"><itemref idref="cover" linear="no"/></spine>
            //
            // 做到这三者，才能保证
            // 1. 封面在阅读器和 Finder 中正常显示
            // 2. 封面在 Calibre 的元数据编辑器中正常显示
            // 3. 封面在 Calibre 的书籍编辑器中正常显示
            if meta.attributes["name"] == "cover" {
                meta.attributes["content"] = "cover-image"
            }
        }
        newXML.addChild(metadata)
        
        polishManifest(in: newXML)
        polishSpine(in: newXML)
        
        let xmlHead = "<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"no\"?>"
        let result = xmlHead + "\n" + newXML.toXMLString()
        try! result.write(to: url, atomically: false, encoding: .utf8)
    }
}

private extension ContentOPF {
    
    func polishManifest(in newXML: XML) {
        let manifestXML = xml.manifest.tryGetXML()
        let newManifestXML = copyXMLWithoutChildren(original: manifestXML)
        newXML.addChild(newManifestXML)
        
        let tocItem = ManifestItem.init(id: "ncxtoc", href: self.tocNCXFileName, mediaType: "application/x-dtbncx+xml")
        newManifestXML.addChild(tocItem.toXML())

        let cssItem = ManifestItem.init(id: "css", href: self.cssFileName, mediaType: "text/css")
        newManifestXML.addChild(cssItem.toXML())

        let coverImageItem = ManifestItem.init(id: "cover-image", href: self.coverFileName, mediaType: "image/jpeg")
        newManifestXML.addChild(coverImageItem.toXML())
        
        for imageURL in imageURLs {
            let fileName = imageURL.lastPathComponent
            let imageItem = ManifestItem.init(id: fileName, href: "Image/" + fileName, mediaType: "image/jpeg")

            newManifestXML.addChild(imageItem.toXML())
        }
        
        let digits = String(chapterFileURLs.count).count
        for (index, chapterFileURL) in chapterFileURLs.enumerated() {
            let id = idFrom(chapterIndex: index, digits: digits)
            let href = chapterFileURL.deletingLastPathComponent().lastPathComponent + "/" + chapterFileURL.lastPathComponent
            let chapterItem = ManifestItem.init(id: id, href: href, mediaType: "application/xhtml+xml")
            
            newManifestXML.addChild(chapterItem.toXML())
        }
    }
    
    func polishSpine(in newXML: XML) {
        let spineXML = xml.spine.tryGetXML()
        let newSpineXML = copyXMLWithoutChildren(original: spineXML)
        newSpineXML.attributes["toc"] = "ncxtoc"
        newXML.addChild(newSpineXML)
        
        let coverItemRef = SpineItemRef.init(idref: "cover", linear: "no")
        newSpineXML.addChild(coverItemRef.toXML())

        let digits = String(chapterFileURLs.count).count
        for (index, _) in chapterFileURLs.enumerated() {
            let id = idFrom(chapterIndex: index, digits: digits)
            let chapterItemRef = SpineItemRef.init(idref: id, linear: "yes")
            
            newSpineXML.addChild(chapterItemRef.toXML())
        }
    }
}

private extension ContentOPF {
    
    func idFrom(chapterIndex: Int, digits: Int) -> String {
        return String(chapterIndex + 1).fillInZeroUntil(meet: digits)
    }
}
