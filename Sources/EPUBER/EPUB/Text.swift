//
//  Chapter.swift
//  EPUBER
//
//  Created by nsfish on 2021/11/21.
//

import Foundation
import PTSwift
import SwiftSoup

class Chapter {
    
    let title: String
    let fileURL: URL
    let isVolume: Bool
    
    init(title: String, fileURL: URL, isVolume: Bool = false) {
        self.title = title
        self.fileURL = fileURL
        self.isVolume = isVolume
    }
}

class Volume {
    
    fileprivate var index = 0
    
    var title = ""
    var fileURL: URL?
    var chapters = [Chapter]()
}

class Text {
    
    let cssFilePosition: String
    let chapterFileURLs: [URL]
    
    var volumes: [Volume]!
    
    init(cssFilePosition: String, chapterFileURLs: [URL]) {
        self.cssFilePosition = cssFilePosition
        self.chapterFileURLs = chapterFileURLs
    }
    
    func polish() {
        let chapters = chapterFileURLs.map { try! polishChapterWithSwiftSoup(at: $0) }
        organizeChaptersIntoVolumes(chapters)
    }
}

private extension Text {
    
    func polishChapterWithSwiftSoup(at url: URL) throws -> Chapter {
        var content = try String(contentsOf: url).replacingOccurrences(of: "\r\n", with: String.endOfLine)
        let doc: Document = try SwiftSoup.parse(content)
        
        // 移除包括内嵌 css 在内的一切内容
        // 只需要 meta 和 css
        let head = doc.head()!
        // 章节分隔页的 title 需要保留，因为 body 里很可能没有 title
        let headTitle = try doc.title()
        
        try head.removeAllChildren()
        try head.append(#"<meta http-equiv="Content-Type" content="text/html; charset=utf-8">"#)
        try head.append(#"<link rel="stylesheet" href=""# + cssFilePosition + #"" type="text/css"/>"#)
        
        let body = doc.body()!
        
        var title = ""
        var isVolume = false
        if let h2 = try body.getElementsByTag("h2").first() {
            title = try h2.text()
        }
        else {
            title = headTitle
        }
        
        // 提取卷/部名或章节名供后续 toc.ncx 处使用
        if !title.isEmpty {
            try doc.title(title)
        }
        
        if let match = title.firstMatch(with: #"第\S*(卷|部|部分|篇)(\s.+)*"#), match.value == title {
            isVolume = true
        }
        else if let match = title.firstMatch(with: #"番外(\s.+)*"#), match.value == title {
            isVolume = true
        }
        else if let match = title.firstMatch(with: #"[上下]册"#), match.value == title {
            isVolume = true
        }
        
        if isVolume {
            content = try! doc.html()
        }
        else {
            // 尽可能移除原有的样式
            let elements = try body.getAllElements().filter { try $0.tagName() != "img" // 图片可能包含一些位置之类的信息
                && $0.tagName() != "a" // 注释
                && $0.tagName() != "ol"
                && $0.tagName() != "li"
                && $0.attr("style") != "page-break-after:always;" // 分页
            }
            try elements.forEach { try $0.removeAllAttributes() }
            
            if let h2 = try body.getElementsByTag("h2").first() {
                try h2.removeAllChildren()
                try h2.append(#"<span class="title-bottom-line">"# + title)
            }
            
            // 修正图片引用的位置
            // from <img src="images/00088.jpg"/>
            // to   <img src="../Image/00088.jpg"/>
            let images = try body.getAllElements().filter { $0.tagName() == "img" }
            try images.forEach { image in
                let imagePath = try image.attr("src")
                let imageURL = URL(fileURLWithPath: imagePath)
                let newImagePath = "../Image/" + imageURL.lastPathComponent
                
                try image.removeAllAttributes()
                try image.attr("src", newImagePath)
            }
            
            content = try! doc.html()
//            if !isVolume {
//                content = content.replacingOccurrences(of: "<p><span>" + title + "</span></p>",
//                                                       with: #"<h2><span class="title-bottom-line">"# + title + #"</span></h2>"#)
//            }
            
            content = try polishNotes(in: content)
        }

        try content.write(to: url, atomically: false, encoding: .utf8)
        
        return Chapter(title: title, fileURL: url, isVolume: isVolume)
    }
    
    func polishNotes(in content: String) throws -> String {
        var resultContent = content
        var doc: Document = try SwiftSoup.parse(resultContent)
                
        // 备注标记和备注内容必须成对出现
        let marks = content.matches(with: #"(?<!【)[①②③]"#)
        let notes = content.matches(with: #"<p>【[①②③].*<\/p>\s\n"#)
        if marks.count != notes.count {
            //TODO: 报错
            print("")
        }
        else if marks.count == 0 {
            return resultContent
        }
                
        // 先检查是否已经存在多看样式的备注, 如果存在, 记下已经存在的备注数量, 后续的备注 id 在这个基础上递增
        var existingNotesCount = 0
        if let element = try doc.getElementsByTag("ol").filter( { $0.hasClass("duokan-footnote-content") }).first {
            existingNotesCount = element.children().array().filter({ $0.tagName() == "li" }).count
        }
        
        // 替换备注标记, 以正则的方式进行
        for (index, mark) in marks.enumerated().reversed() {
            let noteImage = "<sup><a href=\"#footnote_"
                + (existingNotesCount + index).toString() + "\""
                + #"class="duokan-footnote"><img src="../Image/note.png"></a></sup>"#
            let range = Range(mark.original.range, in: resultContent)!
            resultContent = resultContent.replacingOccurrences(of: mark.value, with: noteImage, options: [], range: range)
        }
        
        // 替换备注内容，以 DOM 方式进行
        // 所以需要再次生成 doc
        doc = try SwiftSoup.parse(resultContent)
        var olElement: Element!
        if let element = try doc.getElementsByTag("ol").filter( { $0.hasClass("duokan-footnote-content") }).first {
            olElement = element
        }
        else { // 如果不存在 <ol class="duokan-footnote-content">，就构造一个
            let element = Element.init(Tag("ol"), "")
            try element.attr("class", "duokan-footnote-content")
            olElement = try doc.body()!.appendChild(element)
        }
        
        for (index, note) in notes.enumerated() {
            let noteContent = note.value.firstMatch(with: #"(?<=<p>【[①②③]).*(?=】</p>)"#)?.value ?? ""
            let elementString =  #"<li class="duokan-footnote-item" id="footnote_"#
                + (index + existingNotesCount + 1).toString()
                + "\">"
                + noteContent
                + "</li>"
            
            try olElement.append(elementString)
        }
        // 将修改后的 DOM 转换成字符串
        resultContent = try doc.html()
        
        // 清除掉非多看样式的备注
        notes.forEach { resultContent = resultContent.replacingOccurrences(of: $0.value, with: "") }
        
        return resultContent
    }
    
    /// 将混在一起的卷和章节拆分开来
    func organizeChaptersIntoVolumes(_ chapters: [Chapter]) {
        var volumes = [Volume]()
        
        // 先从所有章节名中提取出卷名，比如
        // 第一卷/部
        // 番外 一个普通人的日常
        for (index, chapter) in chapters.enumerated() {
            let title = chapter.title
            
            let createVolume = {
                let volume = Volume()
                volume.index = index
                volume.title = title
                volume.fileURL = chapter.fileURL
                
                volumes.append(volume)
            }
            
            if chapter.isVolume {
                createVolume()
            }
        }
        
        // 然后根据这些卷的 index 将 chapters 切开分卷
        // 找不到任何一个卷名，就当做一卷
        if volumes.count == 0 {
            let volume = Volume()
            volume.chapters = chapters
            self.volumes = [volume]
        }
        else {
            for (i, volume) in volumes.enumerated() {
                if i < volumes.count - 1 {
                    let start = volume.index + 1
                    
                    let nextVolume = volumes[i + 1]
                    let end = nextVolume.index
                    
                    volume.chapters = Array(chapters[start..<end])
                }
                else if i == volumes.count - 1 {
                    let start = volume.index + 1
                    let end = chapters.endIndex
                    
                    volume.chapters = Array(chapters[start..<end])
                }
            }
            
            self.volumes = volumes
        }
    }
}
