//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final public class JSONContent: Content {
    public var arr: [Any?]
    
    public init(_ arr: [Any?]) { self.arr = arr }
}

extension JSONContent {
    public var count: Int { return self.arr.count }

    public func getContent() -> [Any?] { return self.arr as [Any] }

    public var isCountable: Bool { true }

    public func copy() -> JSONContent { return JSONContent(self.arr) }

    public func splice(_ offset: Int) -> JSONContent {
        let right = JSONContent(self.arr[offset...].map{ $0 })
        self.arr = self.arr[..<offset].map{ $0 }
        return right
    }

    public func merge(with right: Content) -> Bool {
        self.arr = self.arr + (right as! JSONContent).arr
        return true
    }

    public func integrate(with item: Item, _ transaction: Transaction) {}
    
    public func delete(_ transaction: Transaction) {}
    
    public func gc(_ store: StructStore) {}
    
    public func write(_ encoder: UpdateEncoder, offset: Int) throws {
        let len = self.arr.count
        encoder.writeLen(len - offset)
        for i in offset..<len {
            let c = self.arr[i]
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

    public func getRef() -> UInt8 { return 2 }
}

func readContentJSON(_ decoder: UpdateDecoder) throws -> JSONContent {
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
