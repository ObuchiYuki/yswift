//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

extension YDeleteSetDecoder {
    public func readStateVector() throws -> [Int: Int] {
        var ss = [Int:Int]()
        let ssLength = try self.restDecoder.readUInt()
        for _ in 0..<ssLength {
            let client = try self.restDecoder.readUInt()
            let clock = try self.restDecoder.readUInt()
            
            ss[Int(client)] = Int(clock)
        }
        return ss
    }
}
