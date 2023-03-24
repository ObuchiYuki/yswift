//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final public class DocumentContent: Content {
    public var doc: Doc
    public var opts: ContentDocOpts

    public init(_ doc: Doc) {
        if doc._item != nil {
//            console.error('This document was already integrated as a sub-document. You should create a second instance instead with the same guid.')
        }
        self.doc = doc

        var opts = ContentDocOpts()
        if !doc.gc { opts.gc = false }
        if doc.autoLoad { opts.autoLoad = true }
        if doc.meta != nil { opts.meta = doc.meta }
        self.opts = opts
    }
}

extension DocumentContent {
    public var count: Int { 1 }

    public func getContent() -> [Any?] { return [self.doc] }

    public var isCountable: Bool { true }
    
    public func copy() -> DocumentContent { return DocumentContent(createDocFromOpts(guid: self.doc.guid, opts: self.opts)) }

    public func splice(_ offset: Int) -> DocumentContent { fatalError() }

    public func merge(with right: Content) -> Bool { return false }

    public func integrate(with item: Item, _ transaction: Transaction) {
        self.doc._item = item
        transaction.subdocsAdded.insert(self.doc)
        if self.doc.shouldLoad {
            transaction.subdocsLoaded.insert(self.doc)
        }
    }

    public func delete(_ transaction: Transaction) {
        if transaction.subdocsAdded.contains(self.doc) {
            transaction.subdocsAdded.remove(self.doc)
        } else {
            transaction.subdocsRemoved.insert(self.doc)
        }
    }

    public func gc(_ store: StructStore) { }

    public func encode(into encoder: UpdateEncoder, offset: Int) {
        encoder.writeString(self.doc.guid)
        encoder.writeAny(self.opts.toAny())
    }

    public var typeid: UInt8 { 9 }
}

func readContentDoc(_ decoder: UpdateDecoder) throws -> DocumentContent {
    return try DocumentContent(createDocFromOpts(
        guid: decoder.readString(),
        opts: ContentDocOpts.fromAny(decoder.readAny()) 
    ))
}

public struct ContentDocOpts {
    public var gc: Bool?
    public var meta: Any?
    public var autoLoad: Bool?
    public var shouldLoad: Bool?
    
    func toAny() -> Any {
        var dict = [String: Any]()
        dict["gc"] = gc
        dict["meta"] = meta
        dict["autoLoad"] = autoLoad
        dict["shouldLoad"] = shouldLoad
        return dict
    }
    
    static func fromAny(_ content: Any) -> ContentDocOpts {
        guard let dict = content as? [String: Any] else { return ContentDocOpts() }
        
        var opts = ContentDocOpts()
        
        if let gc = dict["gc"] as? Bool { opts.gc = gc }
        if let meta = dict["meta"] { opts.meta = meta }
        if let autoLoad = dict["autoLoad"] as? Bool { opts.autoLoad = autoLoad }
        if let shouldLoad = dict["shouldLoad"] as? Bool { opts.shouldLoad = shouldLoad }
        
        return opts
    }
}

public func createDocFromOpts(guid: String, opts: ContentDocOpts) -> Doc {
    var docOpts = DocOpts()
    docOpts.guid = guid
    if let gc = opts.gc { docOpts.gc = gc }
    if let meta = opts.meta { docOpts.meta = meta }
    if let autoLoad = opts.autoLoad { docOpts.autoLoad = autoLoad }
    docOpts.shouldLoad = opts.shouldLoad ?? opts.autoLoad ?? false
    
    return Doc(opts: docOpts)
}
