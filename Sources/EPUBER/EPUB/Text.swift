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
    
    init(title: String, fileURL: URL) {
        self.title = title
        self.fileURL = fileURL
    }
}

class Volumn {
    
    fileprivate var index = 0
    
    var title = ""
    var fileURL: URL?
    var chapters = [Chapter]()
}

class Text {
    
    let cssFilePosition: String
    let chapterFileURLs: [URL]
    
    var volumns: [Volumn]!
    
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
        try head.removeAllChildren()
        try head.append(#"<meta http-equiv="Content-Type" content="text/html; charset=utf-8">"#)
        try head.append(#"<link rel="stylesheet" href=""# + cssFilePosition + #"" type="text/css"/>"#)
        
        // 移除所有样式
        let body = doc.body()!
        let elements = try body.getAllElements().filter { try $0.tagName() != "a"
            && $0.tagName() != "img"
            && $0.tagName() != "ol"
            && $0.tagName() != "li"
            && $0.attr("style") != "page-break-after:always;"
        }
        try elements.forEach { try $0.removeAllAttributes() }
        
        var title = ""
        if let h2 = try body.getElementsByTag("h2").first() {
            title = try h2.text()
            
            try h2.removeAllChildren()
            try h2.append(#"<span class="title-bottom-line">"# + title)
        }
        
        // 提取卷/部名或章节名供后续 toc.ncx 处使用
        if !title.isEmpty {
            try doc.title(title)
        }
        
        content = try! doc.html()
        try content.write(to: url, atomically: false, encoding: .utf8)
        
        return Chapter(title: title, fileURL: url)
    }
    
    func polishChapter(at url: URL) -> Chapter {
        var content = try! String(contentsOf: url).replacingOccurrences(of: "\r\n", with: String.endOfLine)
        
        // ”第N卷““第N部”的样式需要和“第N章”区分开
        var isVolumn = false
        // 只匹配单行
        // match.value.count > 0 表示确实匹配到了
        // $0.value.count < 10 表示匹配到的内容不会太长
        // 比如"第十八卷"是 OK 的，“第二天我们走了一天路，XXXXXXX到达了城郊结合部”是不行的
        var regex = RE(#">第[\S]*(卷|部)"#, options: [])
        isVolumn = content.matches(with: regex).filter( { $0.value.count > 0 && $0.value.count < 10 }).count > 0
        
        // css 文件位置
        regex = #"<link [\s\S]*css"/>"#
        let css = #"<link rel="stylesheet" href=""# + cssFilePosition + #"" type="text/css"/>"#
        content = content.replacingMatches(of: regex, with: css)
        
        // 清除内置 css 规则
        regex = #"[\s]{0,2}<style[\s\S]*/style>"#
        content = content.replacingMatches(of: regex, with: "")
        
        // 统一标题 h2 样式
        regex = "<h2.*?>(<span.*?>)*"
        content = content.replacingMatches(of: regex, with: #"<h2><span class="title-bottom-line">"#)
        
        regex = #"</.*h2>"#
        content = content.replacingMatches(of: regex, with: "</span></h2>")
        
        // 将”第N卷““第N部”的样式和“第N章”区分开
        if isVolumn {
            regex = #"<h2.*?>(<span.*?>)*(?=(第[\S]*(卷|部)))"#
            content = content.replacingMatches(of: regex, with: #"<h2 class="volumn-title">"#)
            
            regex = "</.*h2>"
            content = content.replacingMatches(of: regex, with: "</h2>")
        }
        
        // 移除 p 的样式和可能存在的空格
        regex = #"<p.*?>[\s]*"#
        content = content.replacingMatches(of: regex, with: "<p>")
        
        // 移除 div 的样式
        regex = "<div.*?>"
        content = content.replacingMatches(of: regex, with: "<div>")
        
        // 移除 body 的样式
        if !isVolumn {
            regex = "<body.*?>"
            content = content.replacingMatches(of: regex, with: "<body>")
        }
        
        // 移除 h1 (目前见到的是将卷名加到章节里)
        regex = "<h1.*</h1>\n"
        content = content.replacingMatches(of: regex, with: "")
        
        // 提取卷/部名或章节名供后续 toc.ncx 处使用
        var title = ""
        if isVolumn {
            regex = "(?<=(<title>)).*?(?=(</))"
            let match = content.firstMatch(with: regex)
            title = match?.value ?? ""
        }
        else {
            regex = #"(?<=(">)).*?(?=(</))"#
            let match = content.firstMatch(with: regex)
            title = match?.value ?? ""
            
            // 统一 title
            regex = #"(?<=<title>)[\s\S]*(?=</title>)"#
            content = content.replacingMatches(of: regex, with: title)
        }
        
        try! content.write(to: url, atomically: false, encoding: .utf8)
        
        return Chapter(title: title, fileURL: url)
    }
    
    /// 将混在一起的卷和章节拆分开来
    func organizeChaptersIntoVolumes(_ chapters: [Chapter]) {
        var volumns = [Volumn]()
        
        // 先从所有章节名中提取出卷名，比如
        // 第一卷/部
        // 番外 一个普通人的日常
        for (index, chapter) in chapters.enumerated() {
            let title = chapter.title
            
            let createVolumn = {
                let volumn = Volumn()
                volumn.index = index
                volumn.title = title
                volumn.fileURL = chapter.fileURL
                
                volumns.append(volumn)
            }
            
            if let match = title.firstMatch(with: #"第\S*(卷|部)(\s.+)*"#), match.value == title {
                createVolumn()
            }
            else if let match = title.firstMatch(with: #"番外(\s.+)*"#), match.value == title {
                createVolumn()
            }
        }
        
        // 然后根据这些卷的 index 将 chapters 切开分卷
        // 找不到任何一个卷名，就当做一卷
        if volumns.count == 0 {
            let volumn = Volumn()
            volumn.chapters = chapters
            self.volumns = [volumn]
        }
        else {
            for (i, volumn) in volumns.enumerated() {
                if i < volumns.count - 1 {
                    let start = volumn.index + 1
                    
                    let nextVolumn = volumns[i + 1]
                    let end = nextVolumn.index
                    
                    volumn.chapters = Array(chapters[start..<end])
                }
                else if i == volumns.count - 1 {
                    let start = volumn.index + 1
                    let end = chapters.endIndex
                    
                    volumn.chapters = Array(chapters[start..<end])
                }
            }
            
            self.volumns = volumns
        }
    }
}
