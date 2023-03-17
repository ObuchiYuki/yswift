//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation


public class Transaction {

    public var doc: Doc
    
    public var deleteSet: DeleteSet = DeleteSet()
    
    public var beforeState: [UInt: UInt] = [:]

    public var afterState: [UInt: UInt] = [:]

    public var changed: [AbstractType: Set<String?>] = [:] // Map<AbstractType_<YEvent<any>>, Set<String?>>

    public var changedParentTypes: [AbstractType: [YEvent]] = [:] //[AbstractType_<YEvent<any>>: YEvent<any][]> = [:]

    public var meta: [AnyHashable: Any] = [:]

    public var local: Bool

    public var subdocsAdded: Set<Doc> = Set()
    public var subdocsRemoved: Set<Doc> = Set()
    public var subdocsLoaded: Set<Doc> = Set()

    public var _mergeStructs: [Struct] = []

    public var origin: Any?

    public init(_ doc: Doc, origin: Any?, local: Bool) {
        self.doc = doc
        self.beforeState = doc.store.getStateVector()
        self.origin = origin
        self.local = local
    }

    public func encodeUpdateMessage(_ encoder: UpdateEncoder) throws -> Bool {
        let hasContent = self.afterState.allSatisfy({ client, clock in self.beforeState[client] != clock })
        if self.deleteSet.clients.count == 0 && !hasContent {
            return false
        }
        self.deleteSet.sortAndMerge()
        try writeStructsFromTransaction(encoder: encoder, transaction: self)
        try self.deleteSet.encode(encoder)
        return true
    }

    public func nextID() -> ID {
        let y = self.doc
        return ID(client: y.clientID, clock: y.store.getState(y.clientID))
    }

    public func addChangedType(_ type: AbstractType, parentSub: String?) {
        let item = type._item
        if item == nil || (item!.id.clock < (self.beforeState[item!.id.client] ?? 0) && !item!.deleted) {
            var changed = self.changed[type] ?? Set<String?>() => {
                self.changed[type] = $0
            }
            changed.insert(parentSub)
            self.changed[type] = changed
        }
    }

    static public func cleanup(_ transactions: Ref<[Transaction]>, i: Int) throws {
        if i >= transactions.count { return }
    
        let transaction = transactions[i]
        let doc = transaction.doc
        let store = doc.store
        let ds = transaction.deleteSet
        let mergeStructs = transaction._mergeStructs
        do {
            ds.sortAndMerge()
            transaction.afterState = transaction.doc.store.getStateVector()
            try doc.emit(Doc.Event.beforeObserverCalls, transaction)
            
            var fs: [() throws -> Void] = []
            
            transaction.changed.forEach{ (itemtype: AbstractType, subs: Set<String?>) in
                fs.append{
                    if itemtype._item == nil || !itemtype._item!.deleted {
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
                        if type._item == nil || !type._item!.deleted {
                            events = events
                                .filter{ event in event.target._item == nil || !event.target._item!.deleted }
                            events
                                .forEach{ event in event.currentTarget = type }
                            
                            events
                                .sort{ event1, event2 in event1.path.count < event2.path.count }
                            
                            type._dEH.callListeners(events, transaction)
                        }
                    }
                }
                
                fs.append{
                    try doc.emit(Doc.Event.afterTransaction, transaction)
                }
            })

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
                let firstChangePos = try max(StructStore.findIndexSS(structs: structs, clock: beforeClock), 1)

                for i in (firstChangePos..<structs.count).reversed() {
                    Struct.tryMerge(withLeft: structs, pos: i)
                }
            }
        })
        
        for _ in 0..<mergeStructs.count {
            let client = mergeStructs[i].id.client, clock = mergeStructs[i].id.clock
            let structs = store.clients[client]!
            let replacedStructPos = try StructStore.findIndexSS(structs: structs, clock: clock)
            if replacedStructPos + 1 < structs.count {
                Struct.tryMerge(withLeft: structs, pos: replacedStructPos + 1)
            }
            if replacedStructPos > 0 {
                Struct.tryMerge(withLeft: structs, pos: replacedStructPos)
            }
        }
        if !transaction.local && transaction.afterState[doc.clientID] != transaction.beforeState[doc.clientID] {
            doc.clientID = generateNewClientID()
        }
        
        try doc.emit(Doc.Event.afterTransactionCleanup, transaction)
        
        if doc.isObserving(Doc.Event.update) {
            let encoder = UpdateEncoderV1()
            let hasContent = try transaction.encodeUpdateMessage(encoder)
            if hasContent {
                try doc.emit(Doc.Event.update, (encoder.toData(), transaction.origin, transaction))
            }
        }
        if doc.isObserving(Doc.Event.updateV2) {
            let encoder = UpdateEncoderV2()
            let hasContent = try transaction.encodeUpdateMessage(encoder)
            if hasContent {
                try doc.emit(Doc.Event.updateV2, (
                    encoder.toData(), transaction.origin, transaction
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
            let subdocevent = Doc.Event.SubDocEvent(
                loaded: subdocsLoaded, added: subdocsAdded, removed: subdocsRemoved
            )
            try doc.emit(Doc.Event.subdocs, (subdocevent, transaction))
            try subdocsRemoved.forEach{ try $0.destroy() }
        }

        if transactions.count <= i + 1 {
            doc._transactionCleanups = .init(value: [])
            try doc.emit(Doc.Event.afterAllTransactions, transactions.map{ $0 })
        } else {
            try Transaction.cleanup(transactions, i: i + 1)
        }
    }
    

    /** Implements the functionality of `y.transact(()->{..})` */
    static public func transact(_ doc: Doc, body: (Transaction) throws -> Void, origin: Any? = nil, local: Bool = true) throws {
        
        var initialCall = false
        
        if doc._transaction == nil {
            initialCall = true
            doc._transaction = Transaction(doc, origin: origin, local: local)
            doc._transactionCleanups.value.append(doc._transaction!)
                        
            if doc._transactionCleanups.count == 1 {
                try doc.emit(Doc.Event.beforeAllTransactions, ())
            }
            try doc.emit(Doc.Event.beforeTransaction, doc._transaction!)
        }
        
        func defering() throws {
            if initialCall {
                let finishCleanup = doc._transaction === doc._transactionCleanups[0]
                doc._transaction = nil
                if finishCleanup {
                    try Transaction.cleanup(doc._transactionCleanups, i: 0)
                }
            }
        }
        
        do {
            try body(doc._transaction!)
            try defering()
        } catch {
            try defering()
            throw error
        }
    }


}

