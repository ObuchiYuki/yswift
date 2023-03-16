//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation
import lib0
import Promise

public struct DocOpts {
    public var gc: Bool = true
    public var gcFilter: (Item) -> Bool = {_ in true }
    public var guid: String = UUID().uuidString
    public var collectionid: String? = nil
    public var meta: Any? = nil
    public var autoLoad: Bool = true
    public var shouldLoad: Bool = true
    
    public init(gc: Bool = true, gcFilter: @escaping (Item) -> Bool = {_ in true }, guid: String = UUID().uuidString, collectionid: String? = nil, meta: Any? = nil, autoLoad: Bool = true, shouldLoad: Bool = true) {
        self.gc = gc
        self.gcFilter = gcFilter
        self.guid = guid
        self.collectionid = collectionid
        self.meta = meta
        self.autoLoad = autoLoad
        self.shouldLoad = shouldLoad
    }
}

public class Doc: Lib0Observable, JSHashable {
    public var gcFilter: (Item) -> Bool
    public var gc: Bool
    public var clientID: UInt
    public var guid: String
    public var collectionid: String?
    public var share: [String: AbstractType] // [String: AbstractType_<YEvent<any>>]
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
    public var _transactionCleanups: [Transaction]
    

    public init(opts: DocOpts = .init()) {
        
        self.gc = opts.gc
        self.gcFilter = opts.gcFilter
        self.clientID = generateNewClientID()
        self.guid = opts.guid
        self.collectionid = opts.collectionid
        self.share = [:]
        self.store = StructStore()
        self._transaction = nil
        self._transactionCleanups = []
        self.subdocs = Set()
        self._item = nil
        self.shouldLoad = opts.shouldLoad
        self.autoLoad = opts.autoLoad
        self.meta = opts.meta
        self.isLoaded = false
        self.isSynced = false
        
        super.init()
        
        self.whenLoaded = Promise{ resolve, _ in
            self.on(Event.load) {
                self.isLoaded = true
                resolve(())
            }
        }
                        
        func provideSyncedPromise() -> Promise<Void, Never> {
            .init{ resolve, _ in
                var disposer: Disposer!
                disposer = self.on(Event.sync, { isSynced in
                    if isSynced == nil || isSynced == true {
                        self.off(Event.sync, disposer)
                        resolve(())
                    }
                })
            }
        }
        
        self.on(Event.sync, { isSynced in
            if isSynced == false && self.isSynced {
                self.whenSynced = provideSyncedPromise()
            }
            self.isSynced = isSynced == nil || isSynced == true
            if !self.isLoaded {
                self.emit(Event.load, ())
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
    public func load() {
        let item = self._item
        if item != nil && !self.shouldLoad {
            (item!.parent as! AbstractType).doc?.transact({ transaction in
                transaction.subdocsLoaded.insert(self)
            }, origin: nil)
        }
        self.shouldLoad = true
    }

    public func getSubdocs() -> Set<Doc> { return self.subdocs }

    public func getSubdocGuids() -> Set<String> {
        return Set(self.subdocs.map{ $0.guid })
        
    }

    public func transact(_ body: (Transaction) throws -> Void, origin: Any? = nil, local: Bool = true) rethrows {
        try Transaction.transact(self, body: body, origin: origin, local: local)
    }

//    get_<T: AbstractType>(name: String, TypeConstructor: T.Type = AbstractType.self) -> T {
//        let type = self.share[name] ?? {
//            let t = TypeConstructor()
//            t._integrate(this, nil)
//            self.share[name] = t
//            return t
//        }()
//
//        let Constr = type.constructor
//        if TypeConstructor != AbstractType && Constr != TypeConstructor {
//            if Constr == AbstractType_ {
//                let t = TypeConstructor()
//                t._map = type._map
//                type._map.forEach((n: Item?) -> {
//                    public func for(_ ; n != nil; n = n.left) {
//                        n.parent = t
//                    }
//                })
//                t._start = type._start
//                public func for(_ var n = t._start; n != nil; n = n.right) {
//                    n.parent = t
//                }
//                t._length = type._length
//                self.share.set(name, t)
//                t._integrate(this, nil)
//                return t
//            } else {
//                throw Error(`Type with the name ${name} has already been defined with a different constructor`)
//            }
//        }
//        return type
//    }

//    getMap<T: Contentable_>(name: String = '') -> YMap<T> { return self.get(name, YMap) }
//
//    getArray<T: Contentable_>(name: String = '') -> YArray<T> { return self.get(name, YArray) }
//
//    public func getXmlFragment(_ name: String = '') -> YXmlFragment { return self.get(name, YXmlFragment) }
//
//    public func getText(_ name: String = '') -> YText { return self.get(name, YText) }

//    public func destroy() {
//        self.subdocs.forEach{ $0.destroy() }
//        let item = self._item
//        if item != nil {
//            self._item = nil
//            let content = item.content as ContentDoc
//            content.doc = Doc(
//                { guid: self.guid, ...content.opts, shouldLoad: false }
//            )
//            content.doc._item = item;
//            (item.parent as AbstractType).doc?.transact(transaction -> {
//                let doc = content.doc
//                if !item.deleted { transaction.subdocsAdded.add(doc) }
//                transaction.subdocsRemoved.add(this)
//            }, nil)
//        }
//        self.emit('destroyed', [true])
//        self.emit('destroy', [this])
//        super.destroy()
//    }
}

extension Doc {
    public enum Event {
        public static let load = Doc.EventName<Void>("load")
        public static let sync = Doc.EventName<Bool?>("sync")
        
        public static let destroy = Doc.EventName<Void>("destroy")
        public static let destroyed = Doc.EventName<Bool>("destroyed")
        
        public static let update = Doc.EventName<(Data, Any?, Transaction)>("update")
        public static let updateV2 = Doc.EventName<(Data, Any?, Transaction)>("updateV2")
        
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
