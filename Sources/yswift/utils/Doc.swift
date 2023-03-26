//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation
import Promise

public struct DocOpts {
    public var gc: Bool = true
    public var gcFilter: (Item) -> Bool
    public var guid: String?
    public var collectionid: String?
    public var meta: Any?
    public var autoLoad: Bool
    public var shouldLoad: Bool
    public var cliendID: Int?
    
    public init(
        gc: Bool = true,
        gcFilter: @escaping (Item) -> Bool = {_ in true },
        guid: String? = nil,
        collectionid: String? = nil,
        meta: Any? = nil,
        autoLoad: Bool = false,
        shouldLoad: Bool = true,
        cliendID: Int? = nil
    ) {
        self.gc = gc
        self.gcFilter = gcFilter
        self.guid = guid
        self.collectionid = collectionid
        self.meta = meta
        self.autoLoad = autoLoad
        self.shouldLoad = shouldLoad
        self.cliendID = cliendID
    }
}

open class Doc: LZObservable, JSHashable {
    public var gcFilter: (Item) -> Bool
    public var gc: Bool
    public var clientID: Int
    public var guid: String
    public var collectionid: String?
    public var share: [String: YObject] // [String: Object_<YEvent<any>>]
    public var store: StructStore
    public var subdocs: Set<Doc>
    public var shouldLoad: Bool
    public var autoLoad: Bool
    public var meta: Any?
    public var isLoaded: Bool
    public var isSynced: Bool
    
    public var whenLoaded: Promise<Void, Never>!
    public var whenSynced: Promise<Void, Never>!
    
    public var _item: Item?
    public var _transaction: Transaction?
    public var _transactionCleanups: Ref<[Transaction]>

    public init(opts: DocOpts = .init()) {
        
        self.gc = opts.gc
        self.gcFilter = opts.gcFilter
        self.clientID = opts.cliendID ?? generateNewClientID()
        self.guid = opts.guid ?? generateDocGuid()
        self.collectionid = opts.collectionid
        self.share = [:]
        self.store = StructStore()
        self._transaction = nil
        self._transactionCleanups = .init(value: [])
        self.subdocs = Set()
        self._item = nil
        self.shouldLoad = opts.shouldLoad
        self.autoLoad = opts.autoLoad
        self.meta = opts.meta
        self.isLoaded = false
        self.isSynced = false
        
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

    /**
     * Notify the parent document that you request to load data into this subdocument (if it is a subdocument).
     *
     * `load()` might be used in the future to request any provider to load the most current data.
     *
     * It is safe to call `load()` multiple times.
     */
    public func load() throws {
        let item = self._item
        if item != nil && !self.shouldLoad {
            try item!.parent!.object!.doc?.transact{ transaction in
                transaction.subdocsLoaded.insert(self)
            }
        }
        self.shouldLoad = true
    }

    public func getSubdocs() -> Set<Doc> { return self.subdocs }

    public func getSubdocGuids() -> Set<String> {
        return Set(self.subdocs.map{ $0.guid })
        
    }

    public func transact(origin: Any? = nil, local: Bool = true, _ body: (Transaction) throws -> Void) throws {
        try Transaction.transact(self, origin: origin, local: local, body)
    }

    // JS実装では TypeConstructor なしで呼び出すとObjectを作った
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
                    var n: Item? = n
                    while n != nil {
                        n!.parent = .object(t)
                        n = n!.left as? Item
                    }
                    
                })
                t._start = type_._start
                var n = t._start; while n != nil {
                    n!.parent = .object(t)
                    n = n!.right as? Item
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

    public func getMap(_ name: String = "") throws -> YMap {
        return try self.get(YMap.self, name: name, make: { YMap.init(nil) })
    }

    public func getArray(_ name: String = "") throws -> YArray {
        return try self.get(YArray.self, name: name, make: { YArray.init() })
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
    
//
//    public func getXmlFragment(_ name: String = '') -> YXmlFragment { return self.get(name, YXmlFragment) }
//

    public override func destroy() throws {
        try self.subdocs.forEach{ try $0.destroy() }
        let item = self._item
        if item != nil {
            self._item = nil
                        
            let content = item!.content as? DocumentContent
            
            // swift add
            var __copyOpts = DocOpts()
            __copyOpts.guid = self.guid
            if let gc = content?.options.gc { __copyOpts.gc = gc }
            if let meta = content?.options.meta { __copyOpts.meta = meta }
            if let autoLoad = content?.options.autoLoad { __copyOpts.autoLoad = autoLoad }
            __copyOpts.shouldLoad = false
            
            let subdoc = Doc(opts: __copyOpts)
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

extension Doc {
    public enum On {
        public static let load = Doc.EventName<Void>("load")
        public static let sync = Doc.EventName<Bool>("sync")
        
        public static let destroy = Doc.EventName<Void>("destroy")
        public static let destroyed = Doc.EventName<Bool>("destroyed")
        
        public static let update = Doc.EventName<(update: Data, origin: Any?, Transaction)>("update")
        public static let updateV2 = Doc.EventName<(update: Data, origin: Any?, Transaction)>("updateV2")
        
        public static let subdocs = Doc.EventName<(SubDocEvent, Transaction)>("subdocs")
        
        public static let beforeObserverCalls = Doc.EventName<Transaction>("beforeObserverCalls")
        
        public static let beforeTransaction = Doc.EventName<Transaction>("beforeTransaction")
        public static let afterTransaction = Doc.EventName<Transaction>("afterTransaction")
                        
        public static let beforeAllTransactions = Doc.EventName<Void>("beforeAllTransactions")
        public static let afterAllTransactions = Doc.EventName<[Transaction]>("afterAllTransactions")
        
        public static let afterTransactionCleanup = Doc.EventName<Transaction>("afterTransactionCleanup")
    

        public struct SubDocEvent {
            public let loaded: Set<Doc>
            public let added: Set<Doc>
            public let removed: Set<Doc>
        }
    }
}
