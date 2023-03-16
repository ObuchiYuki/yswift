//
//  YSwiftError.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

struct YSwiftError: LocalizedError {
    static let unexpectedCase = YSwiftError("Unexpected Case.")
    static let unexpectedContentType = YSwiftError("Unexpected Case.")
    static let lengthExceeded = YSwiftError("Unexpected Content Type.")
    static let integretyCheckFail = YSwiftError("Integrety Check Fail")
    static let originDocGC = YSwiftError("origin Doc must not be garbage collected")
    
    let errorDescription: String
    
    init(_ message: String) {
        self.errorDescription = message
        print(Backtrace(dropFirstSymbols: 5))
    }
}
