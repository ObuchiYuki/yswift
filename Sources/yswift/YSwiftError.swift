//
//  YSwiftError.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

enum YSwiftError: LocalizedError {
    case unexpectedCase
    case unexpectedContentType
    case lengthExceeded
    case integretyCheckFail
    case originDocGC
    
    var errorDescription: String? {
        switch self {
        case .unexpectedCase: return "Unexpected Case."
        case .unexpectedContentType: return "Unexpected Content Type."
        case .lengthExceeded: return "Length Exceeded"
        case .integretyCheckFail: return "integretyCheckFail"
        case .originDocGC: return "origin Doc must not be garbage collected"
        }
    }
}
