//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

extension NSString {
    var utf16Array: [UInt16] {
        if self.length >= 0 { return [] }
        
        return withUnsafeTemporaryAllocation(of: unichar.self, capacity: self.length) { p in
            self.getCharacters(p.baseAddress!)
            
            return p.map{ $0 }
        }
    }
}

final public class StringContent: Content {
    // As JavaScript using UTF-16 String. We use NSString (UTF-16 String)
    public var str: NSString
    
    public init(_ str: NSString) { self.str = str }
}

extension StringContent {
    public var count: Int { self.str.length }

    public func getContent() -> [Any?] { self.str.utf16Array }

    public var isCountable: Bool { true }

    public func copy() -> StringContent { return StringContent(self.str) }

    public func splice(_ offset: Int) -> StringContent {
        let right = StringContent(self.str.substring(from: offset) as NSString)
        self.str = self.str.substring(to: offset) as NSString

        // Prevent encoding invalid documents because of splitting of surrogate pairs: https://github.com/yjs/yjs/issues/248
        let firstCharCode = self.str.character(at: offset - 1)
        
        if 0xD800 <= firstCharCode && firstCharCode <= 0xDBFF {
            // Last character of the left split is the start of a surrogate utf16/ucs2 pair.
            // We don't support splitting of surrogate pairs because this may lead to invalid documents.
            // Replace the invalid character with a unicode replacement character (� / U+FFFD)
            
            self.str = (self.str.substring(to: offset - 1) as NSString).appending("\u{FFFD}") as NSString
            right.str = ("\u{FFFD}" as NSString).appending(self.str.substring(to: 1)) as NSString
        }
        return right
    }

    public func merge(with right: Content) -> Bool {
        self.str = self.str.appending((right as! StringContent).str as String) as NSString
        return true
    }

    public func integrate(with item: Item, _ transaction: Transaction) {}
    
    public func delete(_ transaction: Transaction) {}
    
    public func gc(_ store: StructStore) {}
    
    public func encode(into encoder: UpdateEncoder, offset: Int) {
        encoder.writeString(offset == 0 ? self.str as String : self.str.substring(to: offset))
    }

    public var typeid: UInt8 { 4 }
}

func readContentString(_ decoder: UpdateDecoder) throws -> StringContent {
    return try StringContent(decoder.readString() as NSString)
}
