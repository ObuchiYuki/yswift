//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final public class ContentString: Content {
    public var str: JSString
    
    public init(_ str: JSString) { self.str = str }

    public func getLength() -> UInt { return UInt(self.str.count) }

    public func getContent() -> [Any] { return self.str.data }

    public func isCountable() -> Bool { return true }

    public func copy() -> ContentString { return ContentString(self.str) }

    public func splice(_ offset: UInt) -> ContentString {
        let right = ContentString(self.str.slice(offset))
        self.str = self.str.slice(0, offset)

        // Prevent encoding invalid documents because of splitting of surrogate pairs: https://github.com/yjs/yjs/issues/248
        let firstCharCode = self.str.charCodeAt(offset - 1)
        if 0xD800 <= firstCharCode && firstCharCode <= 0xDBFF {
            // Last character of the left split is the start of a surrogate utf16/ucs2 pair.
            // We don't support splitting of surrogate pairs because this may lead to invalid documents.
            // Replace the invalid character with a unicode replacement character (� / U+FFFD)
            self.str = JSString(self.str.slice(0, offset - 1).data + [0xFFFD])
            // replace right as well
            self.str = JSString([0xFFFD] + self.str.slice(1).data)
        }
        return right
    }

    public func mergeWith(_ right: Content) -> Bool {
        self.str = self.str + (right as! ContentString).str
        return true
    }

    public func integrate(_ transaction: Transaction, item: Item) {}
    
    public func delete(_ transaction: Transaction) {}
    
    public func gc(_ store: StructStore) {}
    
    public func write(_ encoder: UpdateEncoder, offset: UInt) {
        encoder.writeString(offset == 0 ? self.str : self.str.slice(offset))
    }

    public func getRef() -> UInt8 { return 4 }
}

let readContentString: YContentDecoder = decoder -> {
    return ContentString(decoder.readString())
}
