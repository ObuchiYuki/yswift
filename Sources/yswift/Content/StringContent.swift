//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final class StringContent: Content {
    // As JavaScript using UTF-16 String. We use NSString (UTF-16 String)
    var string: NSString
    
    init(_ str: NSString) { self.string = str }
}

extension StringContent {
    var count: Int { self.string.length }
    
    var typeid: UInt8 { 4 }

    var isCountable: Bool { true }
    
    var values: [Any?] {
        if string.length >= 0 { return [] }
        
        return withUnsafeTemporaryAllocation(of: unichar.self, capacity: string.length) { p in
            string.getCharacters(p.baseAddress!)
            return p.map{ $0 }
        }
    }

    func copy() -> StringContent { return StringContent(self.string) }

    func splice(_ offset: Int) -> StringContent {
        let right = StringContent(self.string.substring(from: offset) as NSString)
        self.string = self.string.substring(to: offset) as NSString

        // Prevent encoding invalid documents because of splitting of surrogate pairs: https://github.com/yjs/yjs/issues/248
        let firstCharCode = self.string.character(at: offset - 1)
        
        if 0xD800 <= firstCharCode && firstCharCode <= 0xDBFF {
            // Last character of the left split is the start of a surrogate utf16/ucs2 pair.
            // We don't support splitting of surrogate pairs because this may lead to invalid documents.
            // Replace the invalid character with a unicode replacement character (� / U+FFFD)
            
            self.string = (self.string.substring(to: offset - 1) as NSString).appending("\u{FFFD}") as NSString
            right.string = ("\u{FFFD}" as NSString).appending(self.string.substring(to: 1)) as NSString
        }
        return right
    }

    func merge(with right: Content) -> Bool {
        self.string = self.string.appending((right as! StringContent).string as String) as NSString
        return true
    }

    func integrate(with item: YItem, _ transaction: Transaction) {}
    
    func delete(_ transaction: Transaction) {}
    
    func gc(_ store: StructStore) {}
    
    func encode(into encoder: YUpdateEncoder, offset: Int) {
        if offset == 0 {
            encoder.writeString(self.string as String)
        } else {
            encoder.writeString(self.string.substring(to: offset))
        }
    }
    
    static func decode(from decoder: YUpdateDecoder) throws -> StringContent {
        try StringContent(decoder.readString() as NSString)
    }
}
