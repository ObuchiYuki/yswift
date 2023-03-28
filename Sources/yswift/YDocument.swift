//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation
import Promise

public class YDocument: LZObservable, JSHashable {
    public internal(set) var gc: Bool
    public internal(set) var guid: String
    public internal(set) var clientID: Int
    public internal(set) var collectionid: String?
    public internal(set) var share: [String: YObject]
    public internal(set) var store: YStructStore
    public internal(set) var subdocs: Set<YDocument>
    public internal(set) var shouldLoad: Bool
    public internal(set) var autoLoad: Bool
    public internal(set) var meta: Any?
    public internal(set) var isLoaded: Bool
    public internal(set) var isSynced: Bool
    
    public internal(set) var whenLoaded: Promise<Void, Never>!
    public internal(set) var whenSynced: Promise<Void, Never>!
    
    var _gcFilter: (YItem) -> Bool
    var _item: YItem?
    var _transaction: YTransaction?
    var _transactionCleanups: RefArray<YTransaction>

    public init(_ opts: Options = Options()) {
        
        self.gc = opts.gc
        self.clientID = opts.cliendID ?? YDocument.generateNewClientID()
        self.guid = opts.guid ?? YDocument.generateDocGuid()
        self.collectionid = opts.collectionid
        self.share = [:]
        self.store = YStructStore()
        self.subdocs = Set()
        self.shouldLoad = opts.shouldLoad
        self.autoLoad = opts.autoLoad
        self.meta = opts.meta
        self.isLoaded = false
        self.isSynced = false
        
        self._gcFilter = opts.gcFilter
        self._item = nil
        self._transaction = nil
        self._transactionCleanups = []
        
        super.init()
        
        self.whenLoaded = Promise{ resolve, _ in
            self.on(On.load) {
                self.isLoaded = true
                resolve(())
            }
        }
                        
        func provideSyncedPromise() -> Promise<Void, Never> {
            .init{ resolve, _ in
                var disposer: Disposer!
                disposer = self.on(On.sync, { isSynced in
                    if isSynced {
                        self.off(On.sync, disposer)
                        resolve(())
                    }
                })
            }
        }
        
        self.on(On.sync, { isSynced in
            if isSynced == false && self.isSynced {
                self.whenSynced = provideSyncedPromise()
            }
            self.isSynced = isSynced
            if !self.isLoaded {
                try self.emit(On.load, ())
            }
        })
        self.whenSynced = provideSyncedPromise()
    }

    public func load() throws {
        let item = self._item
        if item != nil && !self.shouldLoad {
            try item!.parent!.object!.doc?.transact{ transaction in
                transaction.subdocsLoaded.insert(self)
            }
        }
        self.shouldLoad = true
    }

    public func getSubdocs() -> Set<YDocument> { return self.subdocs }

    public func getSubdocGuids() -> Set<String> { Set(self.subdocs.map{ $0.guid }) }

    public func transact(origin: Any? = nil, local: Bool = true, _ body: (YTransaction) throws -> Void) throws {
        try YTransaction.transact(self, origin: origin, local: local, body)
    }

    public func get<T: YObject>(_: T.Type, name: String = "", make: () -> T) throws -> T {
        let type_ = try self.share.setIfUndefined(name, {
            let t = make()
            try t._integrate(self, item: nil)
            return t
        }())
        
        if T.self != YObject.self && !(type_ is T) {
            if type(of: type_) == YObject.self {
                let t = make()
                t.storage = type_.storage
                type_.storage.forEach({ _, n in
                    var n: YItem? = n
                    while n != nil {
                        n!.parent = .object(t)
                        n = n!.left as? YItem
                    }
                    
                })
                t._start = type_._start
                var n = t._start; while n != nil {
                    n!.parent = .object(t)
                    n = n!.right as? YItem
                }
                t._length = type_._length
                self.share[name] = t
                try t._integrate(self, item: nil)
                return t
            } else {
                // TODO: throw
                fatalError("Type with the name '\(name)' has already been defined with a different constructor")
            }
        }
        return type_ as! T
    }

    public func getMap<T>(_: T.Type, _ name: String = "") throws -> YMap<T> {
        try YMap(opaque: self.getOpaqueMap(name))
    }
    
    public func getArray<T>(_: T.Type, name: String = "") throws -> YArray<T> {
        try YArray(opaque: self.getOpaqueArray(name))
    }
    
    public func getOpaqueMap(_ name: String = "") throws -> YOpaqueMap {
        return try self.get(YOpaqueMap.self, name: name, make: { YOpaqueMap.init(nil) })
    }

    public func getOpaqueArray(_ name: String = "") throws -> YOpaqueArray {
        return try self.get(YOpaqueArray.self, name: name, make: { YOpaqueArray.init() })
    }
    
    public func getText(_ name: String = "") throws -> YText {
        return try self.get(YText.self, name: name, make: { YText.init() })
    }
    
    
    public func toJSON() -> [String: Any] {
        var doc: [String: Any] = [:]
        self.share.forEach({ key, value in
            doc[key] = value.toJSON()
        })
        return doc
    }

    public override func destroy() throws {
        try self.subdocs.forEach{ try $0.destroy() }
        let item = self._item
        if item != nil {
            self._item = nil
                        
            let content = item!.content as? YDocumentContent
            
            // swift add
            var copiedOptions = Options()
            copiedOptions.guid = self.guid
            if let gc = content?.options.gc { copiedOptions.gc = gc }
            if let meta = content?.options.meta { copiedOptions.meta = meta }
            if let autoLoad = content?.options.autoLoad { copiedOptions.autoLoad = autoLoad }
            copiedOptions.shouldLoad = false
            
            let subdoc = YDocument(copiedOptions)
            content?.document = subdoc
            content?.document._item = item!
            
            try item!.parent!.object!.doc?.transact{ transaction in
                let doc = subdoc
                if !item!.deleted { transaction.subdocsAdded.insert(doc) }
                transaction.subdocsRemoved.insert(self)
            }
        }
        try self.emit(On.destroyed, true)
        try self.emit(On.destroy, ())
        try super.destroy()
    }
}

extension YDocument {
    public enum On {
        public static let load = YDocument.EventName<Void>("load")
        public static let sync = YDocument.EventName<Bool>("sync")
        
        public static let destroy = YDocument.EventName<Void>("destroy")
        public static let destroyed = YDocument.EventName<Bool>("destroyed")
        
        public static let update = YDocument.EventName<(update: YUpdate, origin: Any?, YTransaction)>("update")
        public static let updateV2 = YDocument.EventName<(update: YUpdate, origin: Any?, YTransaction)>("updateV2")
        
        public static let subdocs = YDocument.EventName<(SubDocEvent, YTransaction)>("subdocs")
        
        public static let beforeObserverCalls = YDocument.EventName<YTransaction>("beforeObserverCalls")
        
        public static let beforeTransaction = YDocument.EventName<YTransaction>("beforeTransaction")
        public static let afterTransaction = YDocument.EventName<YTransaction>("afterTransaction")
                        
        public static let beforeAllTransactions = YDocument.EventName<Void>("beforeAllTransactions")
        public static let afterAllTransactions = YDocument.EventName<[YTransaction]>("afterAllTransactions")
        
        public static let afterTransactionCleanup = YDocument.EventName<YTransaction>("afterTransactionCleanup")
    

        public struct SubDocEvent {
            public let loaded: Set<YDocument>
            public let added: Set<YDocument>
            public let removed: Set<YDocument>
        }
    }
}

extension YDocument {
    static func generateDocGuid() -> String {
        #if DEBUG // to remove randomness
        enum __ { static var cliendID: UInt = 0 }
        if NSClassFromString("XCTest") != nil {
            __.cliendID += 1
            return String(__.cliendID)
        }
        print("THIS RUN HAS RANDOMNESS")
        #endif
        return UUID().uuidString
    }
    
    static func generateNewClientID() -> Int {
        #if DEBUG // to remove randomness
        enum __ { static var cliendID: Int = 0 }
        if NSClassFromString("XCTest") != nil {
            __.cliendID += 1
            return __.cliendID
        }
        print("THIS RUN HAS RANDOMNESS")
        #endif
        
        return Int(UInt32.random(in: UInt32.min...UInt32.max))
    }
}

extension YDocument {
    public struct Options {
        public var gc: Bool = true
        public var guid: String?
        public var collectionid: String?
        public var meta: Any?
        public var autoLoad: Bool
        public var shouldLoad: Bool
        public var cliendID: Int?
        
        // pending...
        var gcFilter: (YItem) -> Bool = {_ in true }
        
        public init(gc: Bool = true, guid: String? = nil, collectionid: String? = nil, meta: Any? = nil, autoLoad: Bool = false, shouldLoad: Bool = true, cliendID: Int? = nil) {
            self.gc = gc
            self.guid = guid
            self.collectionid = collectionid
            self.meta = meta
            self.autoLoad = autoLoad
            self.shouldLoad = shouldLoad
            self.cliendID = cliendID
        }
    }

}

