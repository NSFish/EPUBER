//
//  File.swift
//  
//
//  Created by nsfish on 2021/7/4.
//

import Foundation

public class CNNumberToArabicConverter {
    
    fileprivate static let AvailableCNDigits = "零一二三四五六七八九"
    fileprivate static let AvailCNRadixs = ["个", "十", "百", "千", "万", "亿"]
    
    public static let AllowedChineseNumberPattern = "(零|一|二|两|三|四|五|六|七|八|九|十|百|千|万|亿)+"
    
    enum ArabicRadixs: Int, CaseIterable {
        case one = 1
        case ten = 10
        case hundred = 100
        case thousand = 1000
        case tenThousand = 10000
        case oneHundredMillion = 100000000
    }
    
    enum Error: LocalizedError {
        case emptyInput
        case illegalChars
        case unresolvableInput
        
        var errorDescription: String? {
            switch self {
            case .emptyInput:
                return NSLocalizedString("输入的中文字符串为空", comment: "")
            case .illegalChars:
                return NSLocalizedString("输入的中文字符串包含非法字符", comment: "")
            case .unresolvableInput:
                return NSLocalizedString("输入的中文字符串无法解析", comment: "")
            }
        }
    }
    
    public class func convert(_ cnNumber: String) throws -> Int {
        guard !cnNumber.isEmpty else {
            throw Error.emptyInput
        }
        
        guard cnNumber == cnNumber.firstMatch(with: AllowedChineseNumberPattern)?.value else {
            throw Error.illegalChars
        }
        
        if cnNumber.trimmingCharacters(in: CharacterSet.init(charactersIn: AvailableCNDigits)).count == 0 {
            return convertCNNumberWithoutRadix(cnNumber)
        }
        
        return try convertCNNumberWithRadix(cnNumber)
    }
}

//MARK: 主线流程 - 处理带进位的中文数字
extension CNNumberToArabicConverter {
    
    class func convertCNNumberWithRadix(_ cnNumber: String) throws -> Int {
        let cnNumber = polishIfNeeded(cnNumber)
        var digitAndRadixs = try seperateDigitAndRadix(in: cnNumber)
        digitAndRadixs = try addLastRadixIfNeeded(in: digitAndRadixs, originalInput: cnNumber)
        
        return finalize(digitAndRadixs)
    }
    
    /// 对中文数字字符串做预处理
    /// 1. 将口语化的 "两" 替换为 "二"
    /// 2. 将左侧不包含数字的 "十" 替换为 "一十", 让 "十" 从既是数字又是进位的境地中解放出来
    /// - Parameter input: "两千零十万"
    /// - Returns: "二千零一十万"
    class func polishIfNeeded(_ input: String) -> String {
        var result = input.replacingOccurrences(of: "两", with: "二")
        
        let pattern = "(?<![一二三四五六七八九]{1})十"
        result = result.replacingOccurrences(of: pattern, with: "一十", options: .regularExpression)
        
        return result
    }
    
    /// 将中文数字字符串拆分成数组，并补全进位
    /// - Parameter input: "三千三百万"
    /// - Returns: ["三", "千万", "三", "百万"]
    class func seperateDigitAndRadix(in input: String) throws -> [String] {
        var result = [String]()
        
        var storedTempRadix = ""
        var previousCNRadix = ""
        try input.enumerated().reversed().forEach { (index, char) in
            let string = char.toString()
            
            // 略过 "三千零四万" 这样情况下的零
            if string == "零" {}
            else if AvailableCNDigits.contains(string) {
                if !storedTempRadix.isEmpty {
                    var currentCNRadix = storedTempRadix.reversed().toString()
                    currentCNRadix = try complete(currentCNRadix, accordingTo: previousCNRadix)
                    
                    if currentCNRadix.count > 1 {
                        // 在中文语境中，如果进位不是单字，则只可能是
                        // "XXX十万"、"XXX百万"、"XXX千亿" 之类的
                        // 也就是说只会以 "万" 和 "亿" 结尾("兆" 太大了，忽略)
                        if !["万", "亿"].contains(currentCNRadix.last!.toString()) {
                            throw Error.unresolvableInput
                        }
                    }
                    
                    result.append(currentCNRadix)
                    
                    previousCNRadix = currentCNRadix
                    storedTempRadix = ""
                }
                
                result.append(string)
            }
            else {
                storedTempRadix += string
            }
        }
        
        return result.reversed()
    }
    
    /// 为中文数字字符串中最小的数字补上进位
    ///
    /// 比如 "一百五" 和 "一百零五", 都会被拆分成 ["一", "百", "五"], 需要分别补全为
    /// ["一", "百", "五", "十"] 和 ["一", "百", "五", "个"]。
    ///
    /// 基于生活经验，限定补进位范围在 "万" 以下，比如 "三十万五" 就视为错误的输入。
    ///
    /// - Parameters:
    ///   - cnNumber: ["一", "百", "五"]
    ///   - originalString: "一百五" 或 "一百零五"
    /// - Throws: unresolvableInput
    /// - Returns: ["一", "百", "五", "十"] 和 ["一", "百", "五", "个"]
    class func addLastRadixIfNeeded(in cnNumber: [String], originalInput: String) throws -> [String] {
        var cnNumber = cnNumber
        
        if cnNumber.count % 2 != 0 {
            // 如果只有一个元素，说明是个位数，直接补 "个" 即可
            if cnNumber.count == 1 {
                cnNumber.append("个")
            }
            else {
                // 否则先取倒数第二个元素作为最右侧的进位
                let secondToLastDigit = cnNumber[cnNumber.endIndex - 2]
                
                // 然后截取出其右侧的字符串
                let pattern = "(?<=" + secondToLastDigit + ")" + "(零|一|二|两|三|四|五|六|七|八|九)+?" + "$"
                let matchedString = originalInput.firstMatch(with: pattern)?.value ?? ""
                
                // 这里不会出现传入 "XXX零X万" 的情况
                // cnNumber.count % 2 != 0 已经把它们过滤掉了，所以直接补 "个"
                if matchedString.hasPrefix("零") {
                    cnNumber.append("个")
                }
                else {
                    // TODO: 这几个硬编码的 index 要怎么处理好呢?
                    let index = AvailCNRadixs.firstIndex(of: secondToLastDigit) ?? AvailCNRadixs.endIndex
                    if index == AvailCNRadixs.startIndex + 1 {
                        cnNumber.append("个")
                    }
                    else if index > AvailCNRadixs.startIndex + 4 {
                        throw Error.unresolvableInput
                    }
                    else {
                        // 十五（个）
                        // 一百五（十），一百零五（个）
                        // 一千五（百），一千零五（个）
                        // 一万五（千），一万零五（个）
                        cnNumber.append(AvailCNRadixs[index - 1])
                    }
                }
            }
        }
        
        return cnNumber
    }
    
    /// 收官步骤，将之前处理得到的数组加总起来，得到最终的阿拉伯数字
    /// - Parameter cnNumber: "三千三百万"
    /// - Returns: 33000000
    class func finalize(_ cnNumber: [String]) -> Int {
        var partialCNNumbers = [(cnDigit: String, cnRadix: String)]()

        for (index, string) in cnNumber.enumerated() {
            if index % 2 == 0 {
                let partialCNNumber = (cnDigit: string, cnRadix: cnNumber[index + 1])
                partialCNNumbers.append(partialCNNumber)
            }
        }

        let result = partialCNNumbers.map { (cnDigit: String, cnRadix: String) in
            let arabicDigit = arabicDigitFrom(cnDigit: cnDigit) ?? 0
            let arabicRadix = arabicRadixFrom(cnRadix: cnRadix)
            
            return arabicDigit * arabicRadix
        }.reduce(0) { $0 + $1 }
        
        return result
    }
}

//MARK: 支线流程 - 处理不包含进位的中文数字
extension CNNumberToArabicConverter {
    
    /// 将不包含进位的中文数字字符串转换成阿拉伯字符串
    /// - Parameter cnNumber: "一一一"
    /// - Returns: "111"
    class func convertCNNumberWithoutRadix(_ cnNumber: String) -> Int {
        let array = cnNumber.map { (char: Character) -> String in
            let arabicDigit = arabicDigitFrom(cnDigit: char.toString())!
            return arabicDigit.toString()
        }
        
        let arabicNumberString = array.joined()
    
        return Int(arabicNumberString)!
    }
}

//MARK: Helper
extension CNNumberToArabicConverter {
    
    /// 将单个汉字表示的数字转换为阿拉伯数字
    /// - Parameter cnDigit: 比如 "一"
    /// - Returns: "1"
    class func arabicDigitFrom(cnDigit: String) -> Int? {
        // How to figure out the range of a substring in one string and then use it in another
        // https://stackoverflow.com/a/68219387/2135264
        let arabicNumerals = "0123456789"
        
        guard let range = AvailableCNDigits.range(of: cnDigit) else {
            return nil
        }
        
        let pos = AvailableCNDigits.distance(from: AvailableCNDigits.startIndex, to: range.lowerBound)
        let len = AvailableCNDigits.distance(from: range.lowerBound, to: range.upperBound)
        guard
            let lo = arabicNumerals.index(arabicNumerals.startIndex, offsetBy: pos, limitedBy: arabicNumerals.endIndex),
            let hi = arabicNumerals.index(lo, offsetBy: len, limitedBy: arabicNumerals.endIndex)
        else {
            return nil
        }
        
        return Int(arabicNumerals[lo..<hi])
    }
    
    /// 将中文进位转换成阿拉伯数字
    /// - Parameter cnRadix: "十", "百"，或者 "百万" 甚至 "千万亿"
    /// - Returns: 10, 100, 1000000, ...
    class func arabicRadixFrom(cnRadix: String) -> Int {
        let arabicRadixs = ArabicRadixs.allCases.map { $0.rawValue }
        
        var result = 1
        cnRadix.forEach { char in
            let string = char.toString()
            
            let index = AvailCNRadixs.firstIndex(of: string)!
            let arabicRadix = arabicRadixs[index]
            result *= arabicRadix
        }
        
        return result
    }
    
    /// 根据上一个进位，尝试补全当前进位
    ///
    /// 比如 "三千三百万", 根据 "百万" 将 "千" 补全为 "千万"
    /// - Parameters:
    ///   - currentCNRadix: "千"
    ///   - previousCNRadix: "百万"
    /// - Throws: unresolvableInput
    /// - Returns: ["三", "千万", "三", "百万"]
    class func complete(_ currentCNRadix: String, accordingTo previousCNRadix: String) throws -> String {
        guard !previousCNRadix.isEmpty else {
            return currentCNRadix
        }
        
        var currentCNRadix = currentCNRadix
        
        let currentDigit = arabicRadixFrom(cnRadix: currentCNRadix)
        let previousDigit = arabicRadixFrom(cnRadix: previousCNRadix)
        
        if currentDigit > previousDigit {
            // do nothing here
        }
        else if currentDigit == previousDigit {
            // 如果当前进位等于上一个进位，说明输入错误
            // 比如 "三十九十"
            throw Error.unresolvableInput
        }
        else {
            // 如果当前进位小于上一个进位，则为其补全
            //
            // 具体做法是将上一个进位掐去头部，然后把剩下的部分直接拼到当前进位后面
            // 比如 "三千三百万", 当前进位是 "千", 上一个进位是 "百万"
            // 则有 currentDigit = "千" + "万" = "千万"
            var tempDigit = previousCNRadix
            if previousCNRadix.count == 1 {
                // 特别地，如果上一个进位本来就只有一个汉字
                // 比如 "三百零五万" 截取到的是 "万"
                // 则直接使用，do nothing here
            }
            else {
                tempDigit.removeFirst()
            }
            
            // 根据中文的语境，只有以下进位能够作为补位的选择
            // 其他像 "三十三百" 之类的输入，理论上是成立的，但现实生活中不会出现，故报错
            if !["万", "亿", "万亿"].contains(tempDigit) {
                throw Error.unresolvableInput
            }
            
            currentCNRadix += tempDigit
            
            // 若补全后，当前进位 <= 上一个进位，说明字符串有误
            // 比如 "三百三百万"，或者 "三十三百万"
            let currentDigit = arabicRadixFrom(cnRadix: currentCNRadix)
            let previousDigit = arabicRadixFrom(cnRadix: previousCNRadix)
            
            if currentDigit <= previousDigit {
                throw Error.unresolvableInput
            }
        }
        
        return currentCNRadix
    }
}
