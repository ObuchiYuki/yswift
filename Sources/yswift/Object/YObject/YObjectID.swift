//
//  File.swift
//  
//
//  Created by yuki on 2023/03/31.
//

import Foundation

public struct YObjectID: Hashable, CustomStringConvertible {
    let value: UInt64
   
    init(_ value: UInt64) { self.value = value }
   
    static public func == (lhs: YObjectID, rhs: YObjectID) -> Bool { lhs.value == rhs.value }
   
    public func _rawHashValue(seed: Int) -> Int { return value._rawHashValue(seed: seed) }
   
    public var description: String { "YObjectID(\(self.compressedString()))" }
}

extension YObjectID {
    public static let invalidID = YObjectID(UInt64.max >> 8)
   
    public static func publish() -> YObjectID {
        YObjectID(.random(in: 0...(UInt64.max >> 8) - 1))
    }
   
    public static var compressedStringMemo = [UInt64: String]()
       
    func compressedString() -> String {
        if let cached = YObjectID.compressedStringMemo[self.value] { return cached }
        
        let data = withUnsafeBytes(of: self) { Data($0.dropLast()) }
        let newString = (data.base64EncodedString() as NSString).substring(to: 10)
        
        YObjectID.compressedStringMemo[self.value] = newString
        return newString
    }
       
    public init(compressedString: String) {
        let compressedString = compressedString as NSString
        guard var data = Data(base64Encoded: compressedString.appending("==")) else {
           self = .invalidID; assertionFailure("decode failed"); return
        }
        data.append(0)
        let objectID = data.withUnsafeBytes{ $0.load(as: UInt64.self) }
        self = YObjectID(objectID)
   }
}
