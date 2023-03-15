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
    
    public var beforeState: [Int: Int]

    public var afterState: [Int: Int] = [:]

    public var changed: [AbstractType: Set<String?>] = [:] // Map<AbstractType_<YEvent<any>>, Set<String?>>

    public var changedParentTypes: [AbstractType: [YEvent]] = [:] //[AbstractType_<YEvent<any>>: YEvent<any][]> = [:]

    public var meta: [AnyHashable: Any] = [:]

    public var local: Bool

    public var subdocsAdded: Set<Doc> = Set()
    public var subdocsRemoved: Set<Doc> = Set()
    public var subdocsLoaded: Set<Doc> = Set()

    public var _mergeStructs: [Struct] = []

    public var origin: Any

    public init(_ doc: Doc, origin: Any, local: Bool) {
        self.doc = doc
        self.beforeState = doc.store.getStateVector()
        self.origin = origin
        self.local = local
    }

    public func encodeUpdateMessage(_ encoder: UpdateEncoder) -> Bool {
        if self.deleteSet.clients.size == 0 && !Lib0any(self.afterState, (clock, client) -> self.beforeState.get(client) != clock) {
            return false
        }
        self.deleteSet.sortAndMerge()
        writeStructsFromTransaction(encoder, self)
        self.deleteSet.encode(encoder)
        return true
    }

    public func nextID() -> ID {
        let y = self.doc
        return ID(client: y.clientID, clock: y.store.getState(y.clientID))
    }

    public func addChangedType(_ type: AbstractType, parentSub: String?) {
        let item = type._item
        if item == nil || (item.id.clock < (self.beforeState[item.id.client] ?? 0) && !item.deleted) {
            var changed = self.changed[type] ?? Set<String?>() => {
                self.changed[type] = $0
            }
            changed.insert(parentSub)
            self.changed = changed
        }
    }

    static public func cleanup(_ transactions: [Transaction], i: Int) {
        if i < transactions.count {
            let transaction = transactions[i]
            let doc = transaction.doc
            let store = doc.store
            let ds = transaction.deleteSet
            let mergeStructs = transaction._mergeStructs
            do {
                ds.sortAndMerge()
                transaction.afterState = transaction.doc.store.getStateVector()
                doc.emit(Doc.Event.beforeObserverCalls, transaction)
                
                let fs: [() -> Void] = []
                
                transaction.changed.forEach{ itemtype, subs in
                    fs.append({ () -> Void in
                        if itemtype._item == nil || !itemtype._item.deleted {
                            itemtype._callObserver(transaction, subs)
                        }
                    })
                }
                
                fs.append({ () -> Void in
                    // deep observe events
                    transaction.changedParentTypes.forEach{ type, events in
                        var events = events
                        fs.append{ () -> Void in
                            // We need to think about the possibility that the user transforms the
                            // Y.Doc in the event.
                            if type._item == nil || !type._item.deleted {
                                events = events
                                    .filter{ event in event.target._item == nil || !event.target._item.deleted }
                                events
                                    .forEach{ event in event.currentTarget = type }
                                
                                events
                                    .sort{ event1, event2 in event1.path.count < event2.path.count }
                                
                                type._dEH.callListeners(events, transaction)
                            }
                        }
                    }
                    
                    fs.append{
                        doc.emit(Doc.Event.afterTransaction, transaction)
                    }
                })

                var i = 0; while i < fs.count {
                    fs[i]()
                    i += 1
                }
                
            }
            
            // Replace deleted items with ItemDeleted / GC.
            // This is where content is actually remove from the Yjs Doc.
            if doc.gc {
                ds.tryGCDeleteSet(store, doc.gcFilter)
            }
            ds.tryMerge(store)

            // on all affected store.clients props, try to merge
            transaction.afterState.forEach({ client, clock in
                let beforeClock = transaction.beforeState[client] ?? 0
                if beforeClock != clock {
                    let structs = store.clients[client] as! (GC|Item)[]
                    // we iterate from right to left so we can safely remove entries
                    let firstChangePos = max(StructStore.findIndexSS(structs, beforeClock), 1)
                    for i in (firstChangePos..<structs.count).reversed() {
                        Struct.tryMergeWithLeft(structs, i)
                    }
                }
            })
            
            for _ in 0..<mergeStructs.count {
                let client = mergeStructs[i].id.client, clock = mergeStructs[i].id.clock
                let structs = store.clients[client] as! (GC|Item)[]
                let replacedStructPos = StructStore.findIndexSS(structs, clock)
                if replacedStructPos + 1 < structs.length {
                    Struct_.tryMergeWithLeft(structs, replacedStructPos + 1)
                }
                if replacedStructPos > 0 {
                    Struct_.tryMergeWithLeft(structs, replacedStructPos)
                }
            }
            if !transaction.local && transaction.afterState[doc.clientID] != transaction.beforeState[doc.clientID] {
                doc.clientID = generateNewClientID()
            }
            
            doc.emit(Doc.Event.afterTransactionCleanup, transaction)
            if doc.isObserving(Doc.Event.update) {
                let encoder = UpdateEncoderV1()
                let hasContent = transaction.encodeUpdateMessage(encoder)
                if hasContent {
                    doc.emit(Doc.Event.update, (encoder.data, transaction.origin, transaction))
                }
            }
            if doc.isObserving(Doc.Event.updateV2) {
                let encoder = UpdateEncoderV2()
                let hasContent = transaction.encodeUpdateMessage(encoder)
                if hasContent {
                    doc.emit(Doc.Event.updateV2, (
                        encoder.data, transaction.origin, transaction
                    ))
                }
            }
            
            let subdocsAdded = transaction.subdocsAdded
            let subdocsLoaded = transaction.subdocsLoaded
            let subdocsRemoved = transaction.subdocsRemoved
            
            if subdocsAdded.size > 0 || subdocsRemoved.size > 0 || subdocsLoaded.size > 0 {
                subdocsAdded.forEach({ subdoc in
                    subdoc.clientID = doc.clientID
                    if subdoc.collectionid == nil {
                        subdoc.collectionid = doc.collectionid
                    }
                    doc.subdocs.insert(subdoc)
                })
                subdocsRemoved.forEach{ doc.subdocs.delete(subdoc) }
                let subdocevent = Doc.Event.SubDocEvent(
                    loaded: subdocsLoaded, added: subdocsAdded, removed: subdocsRemoved
                )
                doc.emit(Doc.Event.subdocs, (subdocevent, transaction))
                subdocsRemoved.forEach{ $0.destroy() }
            }

            if transactions.length <= i + 1 {
                doc._transactionCleanups = []
                doc.emit(Doc.Event.afterAllTransactions, transactions)
            } else {
                Transaction.cleanup(transactions, i + 1)
            }
        }
    }
    

    /** Implements the functionality of `y.transact(()->{..})` */
    static public func transact(_ doc: Doc, body: (transaction: Transaction) -> Void, origin: Any? = nil, local: Bool = true) {
        let transactionCleanups = doc._transactionCleanups
        var initialCall = false
        if doc._transaction == nil {
            initialCall = true
            doc._transaction = Transaction(doc, origin, local)
            transactionCleanups.push(doc._transaction)
            if transactionCleanups.length == 1 {
                doc.emit(Doc.Event.beforeAllTransactions, ())
            }
            doc.emit(Doc.Event.beforeTransaction, doc._transaction)
        }
        try {
            body(doc._transaction)
        } finally {
            if initialCall {
                let finishCleanup = doc._transaction == transactionCleanups[0]
                doc._transaction = nil
                if finishCleanup { Transaction.cleanup(transactionCleanups, 0) }
            }
        }
    }


}


public protocol JSHashable: AnyObject, Hashable, Equatable {}

extension JSHashable {
    public static == (lhs: Self, rhs: Self) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
