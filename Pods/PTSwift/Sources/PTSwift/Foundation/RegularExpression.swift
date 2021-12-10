//
//  File.swift
//  
//
//  Created by nsfish on 2021/7/4.
//

import Foundation

public typealias RE = NSRegularExpression
public typealias REMatchResult = RegularExpressionMatchResult

public class RegularExpressionMatchResult {
    
    private let string: String
    let original: NSTextCheckingResult
    
    public lazy var value: String = {
        let range = Range(original.range, in: string)!
        return string[range].toString()
    }()
    
    init(string: String, original: NSTextCheckingResult) {
        self.string = string
        self.original = original
    }
}

public extension NSRegularExpression {
    
    convenience init(_ pattern: String) {
        do {
            try self.init(pattern: pattern)
        } catch {
            preconditionFailure("Illegal regular expression: \(pattern).")
        }
    }
}

public extension String {
    
    var fullNSRange: NSRange {
        return NSMakeRange(0, self.utf16.count)
    }
    
    func firstMatch(with pattern: String, options: NSRegularExpression.MatchingOptions = []) -> REMatchResult? {
        let regex = RE.init(pattern)
        return regex.firstMatch(in: self, options: options, range: self.fullNSRange)
            .map { REMatchResult.init(string: self, original: $0) }
    }
    
    func matches(with pattern: String, options: NSRegularExpression.MatchingOptions = []) -> [REMatchResult] {
        let regex = RE.init(pattern)
        return regex.matches(in: self, options: options, range: self.fullNSRange)
            .map { REMatchResult.init(string: self, original: $0) }
    }
}
