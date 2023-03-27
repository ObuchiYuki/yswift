//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation


public class YUpdateMeta: Equatable {
    public static func == (lhs: YUpdateMeta, rhs: YUpdateMeta) -> Bool {
        lhs.from == rhs.from && lhs.to == rhs.to
    }
    
    public var from: [Int: Int]
    public var to: [Int: Int]
    
    init(from: [Int : Int], to: [Int : Int]) {
        self.from = from
        self.to = to
    }
}
