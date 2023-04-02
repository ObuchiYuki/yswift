//
//  File.swift
//
//
//  Created by yuki on 2023/03/31.
//

import Foundation

public struct YObjectID: Hashable, CustomStringConvertible {
    let value: Int
   
    init(_ value: Int) {
        self.value = value
        YObjectID.inMemoryAllocatedIDs.insert(value)
    }
   
    static public func == (lhs: YObjectID, rhs: YObjectID) -> Bool { lhs.value == rhs.value }
   
    public func _rawHashValue(seed: Int) -> Int { return value._rawHashValue(seed: seed) }
   
    public var description: String { "YObjectID(\(self.compressedString()))" }
}

extension YObjectID {
    public static let invalidID = YObjectID(Int.max >> 8)
    
    private static var inMemoryAllocatedIDs = Set<Int>()
   
    public static func publish() -> YObjectID {
        func make() -> Int { Int.random(in: 0...(Int.max >> 8) - 1) }
        var id: Int
        repeat { id = make() } while YObjectID.inMemoryAllocatedIDs.contains(id)
        return YObjectID(id)
    }
}

extension YObjectID {
   
    public static var compressedStringMemo = [Int: String]()
       
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
        let objectID = data.withUnsafeBytes{ $0.load(as: Int.self) }
        self = YObjectID(objectID)
    }
}

extension YObjectID: YElement {
    public func encodeToOpaque() -> Any? { return value }
    public static func decode(from opaque: Any?) -> YObjectID { YObjectID(opaque as! Int) }
}
