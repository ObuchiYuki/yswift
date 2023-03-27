//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final class AnyContent: Content {
    var array: [Any?]
    
    init(_ array: [Any?]) { self.array = array }
}

extension AnyContent {
    var count: Int { return self.array.count }
    
    var typeid: UInt8 { 8 }
    
    var isCountable: Bool { true }

    var values: [Any?] { self.array }
    
    func copy() -> AnyContent { return AnyContent(self.array) }

    func splice(_ offset: Int) -> AnyContent {
        let right = AnyContent(self.array[offset...].map{ $0 })
        self.array = self.array[0..<offset].map{ $0 }
        return right
    }

    func merge(with right: Content) -> Bool {
        self.array = self.array + (right as! AnyContent).array
        return true
    }

    func integrate(with item: Item, _ transaction: Transaction) {}
    
    func delete(_ transaction: Transaction) {}
    
    func gc(_ store: StructStore) {}
    
    func encode(into encoder: YUpdateEncoder, offset: Int) {
        let count = self.array.count
        encoder.writeLen(count - offset)
        for i in offset..<count {
            let c = self.array[i]
            encoder.writeAny(c)
        }
    }
    
    static func decode(from decoder: YUpdateDecoder) throws -> AnyContent {
        let len = try decoder.readLen()
        var cs = [Any?]()
        for _ in 0..<len {
            try cs.append(decoder.readAny())
        }
        return AnyContent(cs)
    }
}
