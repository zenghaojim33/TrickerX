//
//  Regex.swift
//  TrickerX
//
//  Created by Lei Wang on 2017/12/7.
//  Copyright © 2017年 Lei Wang. All rights reserved.
//

import Foundation

enum Regex: String {
    case codableModelStartLine = ".+\\s*:\\s*.*Codable.*\\{"
    case openBracket = "\\{"
    case closeBracket = "\\}"
    case codablePropertyLine = ".*(let|var)\\s+\\w+\\s*(:|=).+"
    case codablePropertyName = "\\w+(?=\\s*:)"
    case closureOrTuple = "\\(.*\\)"
    case spaceOrTabIndentRegex = "^(\\s|\\t)*"
    case toggleComments = "^\\s*\\/\\/"
}
