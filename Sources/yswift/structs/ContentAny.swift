//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final public class ContentAny: Content {
    public var array: [Any?]
    
    public init(_ array: [Any?]) {
        self.array = array
    }

    public func getLength() -> UInt { return UInt(self.array.count) }

    public func getContent() -> [Any] { return self.array as [Any] }

    public func isCountable() -> Bool { return true }

    public func copy() -> ContentAny { return ContentAny(self.array) }

    public func splice(_ offset: UInt) -> ContentAny {
        let right = ContentAny(self.array[Int(offset)...].map{ $0 })
        self.array = self.array[0..<Int(offset)].map{ $0 }
        return right
    }

    public func mergeWith(_ right: Content) -> Bool {
        self.array = self.array + (right as! ContentAny).array
        return true
    }

    public func integrate(_ transaction: Transaction, item: Item) {}
    
    public func delete(_ transaction: Transaction) {}
    
    public func gc(_ store: StructStore) {}
    
    public func write(_ encoder: UpdateEncoder, offset: UInt) {
        let len = self.array.count
        encoder.writeLen(UInt(len) - offset)
        for i in Int(offset)..<len {
            let c = self.array[i]
            encoder.writeAny(c)
        }
    }

    public func getRef() -> UInt8 { return 8 }
}

public func readContentAny(_ decoder: UpdateDecoder) throws -> ContentAny {
    let len = try decoder.readLen()
    var cs = [Any]()
    for _ in 0..<len {
        try cs.append(decoder.readAny())
    }
    return ContentAny(cs)
}
