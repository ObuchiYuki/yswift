//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation

#if DEBUG
let __isTesting = NSClassFromString("XCTest") != nil
#else
let __isTesting = false
#endif
