//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

func anyMap<K, V>(_ m: [K: V], _ f: (K, V) -> Bool) -> Bool {
    for (key, value) in m {
        if f(key, value) {
            return true
        }
    }
    return false
}

func callAll(_ fs: RefArray<() throws -> Void>) throws {
    var handleError: Error?
    var i = 0; while i < fs.count {
        do {
            try fs[i]()
        } catch {
            handleError = error
        }
        i += 1
    }
    if let handleError = handleError {
        throw handleError
    }
}


final public class YTransaction {

    public let doc: Doc
    
    public var local: Bool
    
    public let origin: Any?
    
    public var deleteSet: YDeleteSet = YDeleteSet()
    
    public var beforeState: [Int: Int] = [:]

    public var afterState: [Int: Int] = [:]

    public var changed: [YObject: Set<String?>] = [:] // Map<Object_<YEvent<any>>, Set<String?>>

    public var changedParentTypes: [YObject: [YEvent]] = [:] //[Object_<YEvent<any>>: YEvent<any][]> = [:]

    public var meta: [AnyHashable: Any] = [:]

    public var subdocsAdded: Set<Doc> = Set()
    public var subdocsRemoved: Set<Doc> = Set()
    public var subdocsLoaded: Set<Doc> = Set()
    
    var _mergeStructs: RefArray<YStruct> = []

    init(_ doc: Doc, origin: Any?, local: Bool) {
        self.doc = doc
        self.beforeState = doc.store.getStateVector()
        self.origin = origin
        self.local = local
    }

    func encodeUpdateMessage(_ encoder: YUpdateEncoder) throws -> Bool {
        let hasContent = anyMap(self.afterState, { client, clock in
            self.beforeState[client] != clock
        })
        
        if self.deleteSet.clients.count == 0 && !hasContent {
            return false
        }
        self.deleteSet.sortAndMerge()
        try encoder.writeStructs(from: self)
        try self.deleteSet.encode(into: encoder)
        return true
    }

    func nextID() -> YID {
        let y = self.doc
        return YID(client: y.clientID, clock: y.store.getState(y.clientID))
    }

    func addChangedType(_ type: YObject, parentSub: String?) {
        let item = type.item
        if item == nil || (item!.id.clock < (self.beforeState[item!.id.client] ?? 0) && !item!.deleted) {
            var changed = self.changed[type] ?? Set<String?>() => {
                self.changed[type] = $0
            }
            changed.insert(parentSub)
            self.changed[type] = changed
        }
    }

    static func cleanup(_ transactions: RefArray<YTransaction>, i: Int) throws {
        if i >= transactions.count { return }
    
        let transaction = transactions[i]
        let doc = transaction.doc
        let store = doc.store
        let ds = transaction.deleteSet
        let mergeStructs = transaction._mergeStructs
        
        func defering() throws {
            // Replace deleted items with ItemDeleted / GC.
            // This is where content is actually remove from the Yjs Doc.
            if doc.gc {
                try ds.tryGCDeleteSet(store, gcFilter: doc.gcFilter)
            }
            try ds.tryMerge(store)
            
            
            // on all affected store.clients props, try to merge
            try transaction.afterState.forEach({ client, clock in
                let beforeClock = transaction.beforeState[client] ?? 0
                if beforeClock != clock {
                    let structs = store.clients[client]!
                    // we iterate from right to left so we can safely remove entries
                    let firstChangePos = try max(YStructStore.findIndexSS(structs: structs, clock: beforeClock), 1)

                    for i in (firstChangePos..<structs.count).reversed() {
                        YStruct.tryMerge(withLeft: structs, pos: i)
                    }
                }
            })
            
            
            for i in 0..<mergeStructs.count {
                let client = mergeStructs[i].id.client, clock = mergeStructs[i].id.clock
                let structs = store.clients[client]!
                let replacedStructPos = try YStructStore.findIndexSS(structs: structs, clock: clock)
                if replacedStructPos + 1 < structs.count {
                    YStruct.tryMerge(withLeft: structs, pos: replacedStructPos + 1)
                }
                
                if replacedStructPos > 0 {
                    YStruct.tryMerge(withLeft: structs, pos: replacedStructPos)
                }
            }
            if !transaction.local && transaction.afterState[doc.clientID] != transaction.beforeState[doc.clientID] {
                doc.clientID = generateNewClientID()
            }
            
            try doc.emit(Doc.On.afterTransactionCleanup, transaction)
            
            if doc.isObserving(Doc.On.update) {
                let encoder = YUpdateEncoderV1()
                
                let hasContent = try transaction.encodeUpdateMessage(encoder)
                
                if hasContent {
                    try doc.emit(Doc.On.update, (encoder.toUpdate(), transaction.origin, transaction))
                }
            }
            if doc.isObserving(Doc.On.updateV2) {
                let encoder = YUpdateEncoderV2()
                let hasContent = try transaction.encodeUpdateMessage(encoder)
                if hasContent {
                    try doc.emit(Doc.On.updateV2, (
                        encoder.toUpdate(), transaction.origin, transaction
                    ))
                }
            }
            
            let subdocsAdded = transaction.subdocsAdded
            let subdocsLoaded = transaction.subdocsLoaded
            let subdocsRemoved = transaction.subdocsRemoved
            
            if subdocsAdded.count > 0 || subdocsRemoved.count > 0 || subdocsLoaded.count > 0 {
                subdocsAdded.forEach({ subdoc in
                    subdoc.clientID = doc.clientID
                    if subdoc.collectionid == nil {
                        subdoc.collectionid = doc.collectionid
                    }
                    doc.subdocs.insert(subdoc)
                })
                subdocsRemoved.forEach{ doc.subdocs.remove($0) }
                let subdocevent = Doc.On.SubDocEvent(
                    loaded: subdocsLoaded, added: subdocsAdded, removed: subdocsRemoved
                )
                try doc.emit(Doc.On.subdocs, (subdocevent, transaction))
                try subdocsRemoved.forEach{ try $0.destroy() }
            }

            if transactions.count <= i + 1 {
                doc._transactionCleanups = []
                try doc.emit(Doc.On.afterAllTransactions, transactions.map{ $0 })
            } else {
                try YTransaction.cleanup(transactions, i: i + 1)
            }
        }
        
        do {
            ds.sortAndMerge()
            transaction.afterState = transaction.doc.store.getStateVector()
            try doc.emit(Doc.On.beforeObserverCalls, transaction)
            
            let fs: RefArray<() throws -> Void> = []
            
            transaction.changed.forEach{ (itemtype: YObject, subs: Set<String?>) in
                fs.append{
                    if itemtype.item == nil || !itemtype.item!.deleted {
                        try itemtype._callObserver(transaction, _parentSubs: subs)
                    }
                }
            }
            
            fs.append({
                // deep observe events
                transaction.changedParentTypes.forEach{ type, events in
                    var events = events
                    fs.append{ () -> Void in
                        // We need to think about the possibility that the user transforms the
                        // Y.Doc in the event.
                        if type.item == nil || !type.item!.deleted {
                            events = events
                                .filter{ event in event.target.item == nil || !event.target.item!.deleted }
                            events
                                .forEach{ event in event.currentTarget = type }
                            
                            events
                                .sort{ event1, event2 in event1.path.count < event2.path.count }
                            
                            try type._deepEventHandler.callListeners((events: events, transaction))
                        }
                    }
                }
                
                fs.append{
                    try doc.emit(Doc.On.afterTransaction, transaction)
                }
            })

            // callAll
            try callAll(fs)
        } catch {
            try defering()
            throw error
        }
        
        try defering()
    }
    

    /** Implements the functionality of `y.transact(()->{..})` */
    static func transact(_ doc: Doc, origin: Any? = nil, local: Bool = true, _ body: (YTransaction) throws -> Void) throws {
        
        var initialCall = false
        
        if doc._transaction == nil {
            initialCall = true
            doc._transaction = YTransaction(doc, origin: origin, local: local)
            doc._transactionCleanups.value.append(doc._transaction!)
                        
            if doc._transactionCleanups.count == 1 {
                try doc.emit(Doc.On.beforeAllTransactions, ())
            }
            try doc.emit(Doc.On.beforeTransaction, doc._transaction!)
        }
        
        func defering() throws {
            if initialCall {
                let finishCleanup = doc._transaction === doc._transactionCleanups[0]
                doc._transaction = nil
                if finishCleanup {
                    try YTransaction.cleanup(doc._transactionCleanups, i: 0)
                }
            }
        }
        
        do {
            try body(doc._transaction!)
        } catch {
            try defering()
            throw error
        }
        try defering()
        
    }
}

