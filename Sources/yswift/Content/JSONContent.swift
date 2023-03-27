//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final class JSONContent: Content {
    var array: [Any?]
    
    init(_ arr: [Any?]) { self.array = arr }
}

extension JSONContent {
    var count: Int { self.array.count }

    var isCountable: Bool { true }
    
    var typeid: UInt8 { 2 }
    
    var values: [Any?] { self.array }

    func copy() -> JSONContent { JSONContent(self.array) }

    func splice(_ offset: Int) -> JSONContent {
        let right = JSONContent(self.array[offset...].map{ $0 })
        self.array = self.array[..<offset].map{ $0 }
        return right
    }

    func merge(with right: Content) -> Bool {
        self.array = self.array + (right as! JSONContent).array
        return true
    }

    func integrate(with item: Item, _ transaction: Transaction) {}
    
    func delete(_ transaction: Transaction) {}
    
    func gc(_ store: StructStore) {}
    
    func encode(into encoder: UpdateEncoder, offset: Int) throws {
        let len = self.array.count
        encoder.writeLen(len - offset)
        for i in offset..<len {
            let c = self.array[i]
            if let c = c {
                let jsonData = try JSONSerialization.data(withJSONObject: c, options: [.fragmentsAllowed])
                let jsonString = String(data: jsonData, encoding: .utf8)!
                encoder.writeString(jsonString)
            } else {
                encoder.writeString("undefined")
            }
            encoder.writeString(c == nil ? "undefined" : String(data: try JSONSerialization.data(withJSONObject: c!, options: [.fragmentsAllowed]), encoding: .utf8)!)
        }
    }

    static func decode(from decoder: YUpdateDecoder) throws -> JSONContent {
        let len = try decoder.readLen()
        var cs: [Any?] = []
        for _ in 0..<len {
            let c = try decoder.readString()
            if c == "undefined" {
                cs.append(nil)
            } else {
                try cs.append(JSONSerialization.jsonObject(with: c.data(using: .utf8)!, options: [.fragmentsAllowed]))
            }
        }
        return JSONContent(cs)
    }
}
