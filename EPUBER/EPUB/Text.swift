//
//  Chapter.swift
//  EPUBER
//
//  Created by nsfish on 2021/11/21.
//

import Foundation
import PTSwift

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
        var chapters = [Chapter]()
        
        chapterFileURLs.forEach {
            chapters.append(polishChapter(at: $0))
        }
        
        organizeChaptersIntoVolumes(chapters)
    }
}

private extension Text {
    
    func polishChapter(at url: URL) -> Chapter {
        var content = try! String(contentsOf: url).replacingOccurrences(of: "\r\n", with: "\n")
        
        // 过滤掉一些存在特定 css 规则的文件，比如《诡秘之主》的章节分隔页
        var regex = RE("第[\\S]*(卷|部)")
        let shouldIgnoreCertainCSSRules = content.matches(with: regex).count > 0
        
        // css 文件位置
        regex = RE("<link rel=\"stylesheet\"(.|\n)*css\"/>")
        let css = "<link rel=\"stylesheet\" href=\"" + cssFilePosition + "\" type=\"text/css\"/>"
        content = content.replacingMatches(of: regex, with: css)
        
        // 清除内置 css 规则
        regex = RE("[\\s]{0,2}<style(.|\n)*/style>")
        content = content.replacingMatches(of: regex, with: "")

        // 统一标题 h2 样式
        regex = RE("<h2.*?>(<span.*?>)*")
        content = content.replacingMatches(of: regex, with: "<h2><span class=\"title-bottom-line\">")

        regex = RE("</.*h2>")
        content = content.replacingMatches(of: regex, with: "</span></h2>")
        
        // 将”第N卷“的样式和章节标题区分开
        if !shouldIgnoreCertainCSSRules {
            regex = RE("<h2.*?>(<span.*?>)*(?=(第[\\S]*(卷|部)))")
            content = content.replacingMatches(of: regex, with: "<h2 class=\"volumn-title\">")

            regex = RE("</.*h2>")
            content = content.replacingMatches(of: regex, with: "</h2>")
        }
        
        // 移除 p 的样式和可能存在的空格
        regex = RE("<p.*?>[\\s]*")
        content = content.replacingMatches(of: regex, with: "<p>")
        
        // 移除 div 的样式
        regex = RE("<div.*?>")
        content = content.replacingMatches(of: regex, with: "<div>")
        
        // 移除 body 的样式
        if !shouldIgnoreCertainCSSRules {
            regex = RE("<body.*?>")
            content = content.replacingMatches(of: regex, with: "<body>")
        }
        
        // 移除 h1 的样式(目前见到的是将卷名加到章节里)
        regex = RE("<h1.*</h1>\n")
        content = content.replacingMatches(of: regex, with: "")
        
        // 提取章节名供后续 toc.ncx 处使用
        var title = ""
        if shouldIgnoreCertainCSSRules {
            regex = RE("(?<=(<title>)).*?(?=(</))")
            let match = content.firstMatch(with: regex)
            title = match?.value ?? ""
        }
        else {
            regex = RE("(?<=(\">)).*?(?=(</))")
            let match = content.firstMatch(with: regex)
            title = match?.value ?? ""
            
            // 统一 title
            regex = RE("(?<=<title>)(.|\n)*(?=</title>)")
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
            
            if let match = title.firstMatch(with: RE("第\\S*(卷|部)(\\s.+)*")), match.value == title {
                createVolumn()
            }
            else if let match = title.firstMatch(with: RE("番外(\\s.+)*")), match.value == title {
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
