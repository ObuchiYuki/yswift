//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

func findRootTypeKey(type: YObject) throws -> String {
    for (key, value) in type.doc!.share {
        if value == type {
            return key
        }
    }
    throw YSwiftError.unexpectedCase
}
