//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final class DocumentContent: Content {
    var document: Doc
    var options: Options

    init(_ doc: Doc) {
        if doc._item != nil { print("This document was already integrated as a sub-document.") }
        
        self.document = doc
        self.options = Options(copyFrom: doc)
    }
}

extension DocumentContent {
    var count: Int { 1 }
    
    var typeid: UInt8 { 9 }
    
    var isCountable: Bool { true }

    var values: [Any?] { return [self.document] }
    
    func copy() -> DocumentContent {
        let options = self.options.documentOptions(guid: self.document.guid)
        return DocumentContent(Doc(opts: options))
    }

    func splice(_ offset: Int) -> DocumentContent { fatalError() }

    func merge(with right: Content) -> Bool { return false }

    func integrate(with item: YItem, _ transaction: YTransaction) {
        self.document._item = item
        transaction.subdocsAdded.insert(self.document)
        if self.document.shouldLoad {
            transaction.subdocsLoaded.insert(self.document)
        }
    }

    func delete(_ transaction: YTransaction) {
        if transaction.subdocsAdded.contains(self.document) {
            transaction.subdocsAdded.remove(self.document)
        } else {
            transaction.subdocsRemoved.insert(self.document)
        }
    }

    func gc(_ store: StructStore) {}

    func encode(into encoder: YUpdateEncoder, offset: Int) {
        encoder.writeString(self.document.guid)
        encoder.writeAny(self.options.encode())
    }
    
    static func decode(from decoder: YUpdateDecoder) throws -> DocumentContent {
        let guid = try decoder.readString()
        let options = try Options.decode(decoder.readAny()).documentOptions(guid: guid)
        return DocumentContent(Doc(opts: options))
    }
}


extension DocumentContent {
    struct Options {
        var gc: Bool?
        var meta: Any?
        var autoLoad: Bool?
        var shouldLoad: Bool?
        
        func encode() -> Any {
            var dict = [String: Any]()
            dict["gc"] = gc
            dict["meta"] = meta
            dict["autoLoad"] = autoLoad
            dict["shouldLoad"] = shouldLoad
            return dict
        }
        
        func documentOptions(guid: String) -> DocOpts {
            var options = DocOpts()
            options.guid = guid
            if let gc = self.gc { options.gc = gc }
            if let meta = self.meta { options.meta = meta }
            if let autoLoad = self.autoLoad { options.autoLoad = autoLoad }
            options.shouldLoad = self.shouldLoad ?? self.autoLoad ?? false
            return options
        }

        static func decode(_ content: Any?) -> Options {
            guard let dict = content as? [String: Any?] else { return Options() }
            var options = Options()
            options.gc = dict["gc"] as? Bool
            options.meta = dict["meta"] ?? nil
            options.autoLoad = dict["autoLoad"] as? Bool
            options.shouldLoad = dict["shouldLoad"] as? Bool
            return options
        }
        
        init() {}
        init(copyFrom doc: Doc) {
            if !doc.gc { self.gc = false }
            if doc.autoLoad { self.autoLoad = true }
            if doc.meta != nil { self.meta = doc.meta }
        }
    }
}
