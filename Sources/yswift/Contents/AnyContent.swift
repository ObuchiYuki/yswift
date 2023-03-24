//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final public class AnyContent: Content {
    public var array: [Any?]
    
    public init(_ array: [Any?]) {
        self.array = array
    }
}

extension AnyContent {
    public var count: Int { return self.array.count }
    
    public var typeid: UInt8 { 8 }
    
    public var isCountable: Bool { true }

    
    public func values() -> [Any?] { self.array }
    
    public func copy() -> AnyContent { return AnyContent(self.array) }

    public func splice(_ offset: Int) -> AnyContent {
        let right = AnyContent(self.array[offset...].map{ $0 })
        self.array = self.array[0..<offset].map{ $0 }
        return right
    }

    public func merge(with right: Content) -> Bool {
        self.array = self.array + (right as! AnyContent).array
        return true
    }

    public func integrate(with item: Item, _ transaction: Transaction) {}
    
    public func delete(_ transaction: Transaction) {}
    
    public func gc(_ store: StructStore) {}
    
    public func encode(into encoder: UpdateEncoder, offset: Int) {
        let len = self.array.count
        encoder.writeLen(len - offset)
        for i in offset..<len {
            let c = self.array[i]
            encoder.writeAny(c)
        }
    }
    
    public static func decode(from decoder: UpdateDecoder) throws -> AnyContent {
        let len = try decoder.readLen()
        var cs = [Any?]()
        for _ in 0..<len {
            try cs.append(decoder.readAny())
        }
        return AnyContent(cs)
    }
}
