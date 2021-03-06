//
//  SourceEditorCommand.swift
//  Codable
//
//  Created by Lei Wang on 2017/11/24.
//  Copyright © 2017年 Lei Wang. All rights reserved.
//

import Foundation
import XcodeKit
import AppKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        let command = Command.init(rawValue: invocation.commandIdentifier)
        command?.perform(with: invocation, completionHandler: completionHandler)
        
    }
    
}


private let Github = "https://github.com/wleii/TrickerX"

enum TrickerXError: CustomDebugStringConvertible, CustomStringConvertible {
    case noSelectionFound
    case notFoundCodableModel
    case codablePropertyEmpty
    
    var localizedDescription: String {
        return description
    }
    
    var description: String {
        switch self {
        case .noSelectionFound:
            return "Not found selection line where to make CodingKeys"
        case .notFoundCodableModel:
            return "Not found codable model. Please add codable protocol where your model want to inherit"
        case .codablePropertyEmpty:
            return "Not found available codable properties. If you have a doubt about this, please check the documents: \(Github)"
        }    }
    var debugDescription: String {
        return description
    }
    
    private var errorCode: Int {
        return 404
    }
    
    var asNSError: NSError {
        let domain = "com.rayternet.codable.error"
        let userInfo = [NSLocalizedDescriptionKey: description]
        return NSError(domain: domain, code: errorCode, userInfo: userInfo)
    }
}


private extension Command {
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        switch self {
        case .makeCodingKeys(let isSortingKey):
            guard let textRange = invocation.buffer.selections.firstObject as? XCSourceTextRange else {
                completionHandler(TrickerXError.noSelectionFound.asNSError)
                return
            }
            var startLine = textRange.start.line
            
            var bracketCount: Int = 0
            var isMatchCodableModelStartLine: Bool = false
            var enumCase: [(key: String, value: String)] = []
            
            while startLine >= 0 {
                guard let lineText = invocation.buffer.lines[startLine] as? String else { startLine -= 1; continue }
                
                
                // toggle comments
                if !lineText.match(regex: .toggleComments).isNilOrEmpty {
                    startLine -= 1
                    continue
                }
                
                // find { or }
                let closeBracket: [String] = lineText.match(regex: Regex.closeBracket.rawValue)
                let openBracket: [String] = lineText.match(regex: Regex.openBracket.rawValue)
                
                bracketCount += closeBracket.count
           
                if bracketCount > 0 {
                    // not full {} continue ⬆️ parse
                    bracketCount -= openBracket.count
                    startLine -= 1
                    continue
                }
                if !lineText.match(regex: .codableModelStartLine).isNilOrEmpty {
                    // the end, then break
                    isMatchCodableModelStartLine = true
                    break
                }
                
                //
                if !lineText.match(regex: .closureOrTuple).isNilOrEmpty {
                    startLine -= 1
                    continue
                }
                
                //
                let codablePropertyLine = lineText.match(regex: .codablePropertyLine).unwrappedOrEmpty
                if codablePropertyLine.isEmpty {
                    startLine -= 1
                    continue
                }
                
                // parse property name
                let propertyName = codablePropertyLine.match(regex: .codablePropertyName).unwrappedOrEmpty

                let rawValue: String
                // check: is exist custom key?
                if let customRawValue = codablePropertyLine.match(regex: .customKey)?.match(regex: "\\w+"), !customRawValue.isEmpty {
                    rawValue = customRawValue
                    let splitStrings = codablePropertyLine.split(separator: "/")
                    invocation.buffer.lines[startLine] = splitStrings.first!
                }else {
                    let propertyRawValue = propertyName.snakeCased().unwrappedOrEmpty
                    rawValue = propertyRawValue
                }
                enumCase.append((key: propertyName, value: rawValue))
                
                // coontinue
                startLine -= 1
                
            }
            
            guard isMatchCodableModelStartLine else {
                // not match codable model start line
                completionHandler(TrickerXError.notFoundCodableModel.asNSError)
                return
            }
            
            guard !enumCase.isEmpty else {
                // codable keys empty
                completionHandler(TrickerXError.codablePropertyEmpty.asNSError)
                return
            }
            
            
            let startSelection = textRange.start.line
            let updateSelectionIndexs: [Int] = Array(startLine...startLine+(enumCase.count + 2))
            
            let indentSpaces = (invocation.buffer.lines[textRange.start.line] as! String).match(regex: .spaceOrTabIndent).unwrappedOrEmpty.replacingOccurrences(of: "\n", with: "")
            let caseIndentSpaces = repeatElement(" ", count: invocation.buffer.indentationWidth).joined()
            if isSortingKey {
                enumCase = enumCase.sorted(by: {$0.0 < $1.1})
            }else {
                enumCase = enumCase.reversed()
            }
            var lines = enumCase.reduce("\(indentSpaces)enum CodingKeys: String, CodingKey {\n") { (result, dict) -> String in
                if dict.key != dict.value {
                    return result.appending("\(indentSpaces)\(caseIndentSpaces)case \(dict.key) = \"\(dict.value)\"\n")
                }else {
                    return result.appending("\(indentSpaces)\(caseIndentSpaces)case \(dict.key)\n")
                }
            }
            lines += "\(indentSpaces)}"
            invocation.buffer.lines.insert(lines, at: startSelection)
            
            let textRanges = updateSelectionIndexs.map { (index) -> XCSourceTextRange in
                let sourceTextRange = XCSourceTextRange()
                sourceTextRange.start = XCSourceTextPosition(line: index, column: 0)
                sourceTextRange.end = XCSourceTextPosition(line: index, column: 0)
                return sourceTextRange
            }
            invocation.buffer.selections.setArray(textRanges)
            
            completionHandler(nil)
        case .readme:
            NSWorkspace.shared.open(URL.init(string: Github)!)
            completionHandler(nil)
        }
    }
}


