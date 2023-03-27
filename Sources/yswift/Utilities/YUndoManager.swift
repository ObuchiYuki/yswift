//
//  File.swift
//  
//
//  Created by yuki on 2023/03/17.
//

import Foundation

public protocol Object_or_ObjectArray {}
extension YObject: Object_or_ObjectArray {}
extension [YObject]: Object_or_ObjectArray {}

extension Object_or_ObjectArray {
    var doc: YDocument? {
        if let type = self as? YObject {
            return type.doc
        }
        if let typea = self as? [YObject] {
            return typea[0].doc
        }
        return nil
    }
    
    var asObjectArray: [YObject] {
        if let type = self as? YObject {
            return [type]
        }
        if let typea = self as? [YObject] {
            return typea
        }
        fatalError()
    }
}

final class StructRedone {
    let item: YItem
    let diff: Int
    
    init(item: YItem, diff: Int) {
        self.item = item
        self.diff = diff
    }
}

func followRedone(store: YStructStore, id: YID) throws -> StructRedone {
    var nextID: YID? = id
    var diff = 0
    var item: YStruct? = nil
    repeat {
        if diff > 0 {
            nextID = YID(client: nextID!.client, clock: nextID!.clock + diff)
        }
        item = try store.find(nextID!)
        diff = Int(nextID!.clock - item!.id.clock)
        nextID = (item as? YItem)?.redone
    } while (nextID != nil && item is YItem)
    
    return StructRedone(item: item as! YItem, diff: diff)
}

public class StackItem {
    public var deletions: YDeleteSet
    public var insertions: YDeleteSet

    public var meta: [String: Any]

    public init(_ deletions: YDeleteSet, insertions: YDeleteSet) {
        self.insertions = insertions
        self.deletions = deletions
        self.meta = [:]
    }
}

final public class YUndoManager: LZObservable, JSHashable {
    
    public private(set) var undoing: Bool
    public private(set) var redoing: Bool
    public private(set) var doc: YDocument
    public private(set) var lastChange: Date
    public private(set) var ignoreRemoteMapChanges: Bool

    private let scope: RefArray<YObject> = []
    private let deleteFilter: (YItem) -> Bool
    private var trackedOrigins: Ref<Set<AnyHashable?>>
    private var captureTransaction: (YTransaction) -> Bool
    private var undoStack: Ref<[StackItem]>
    private var redoStack: Ref<[StackItem]>
    
    private let captureTimeout: TimeInterval
    private var afterTransactionDisposer: LZObservable.Disposer!

    public init(typeScope: Object_or_ObjectArray, options: Options) {
        self.deleteFilter = options.deleteFilter
        self.trackedOrigins = options.trackedOrigins
        self.captureTransaction = options.captureTransaction
        self.undoStack = .init(value: [])
        self.redoStack = .init(value: [])
        self.undoing = false
        self.redoing = false
        self.doc = options.doc ?? typeScope.doc!
        self.lastChange = Date.distantPast
        self.ignoreRemoteMapChanges = options.ignoreRemoteMapChanges
        self.captureTimeout = options.captureTimeout
        
        super.init()
        
        self.addToScope(typeScope)
        self.trackedOrigins.value.insert(self)
        
        self.afterTransactionDisposer = self.doc.on(YDocument.On.afterTransaction) { transaction in
            // Only track certain transactions
            if (
                !self.captureTransaction(transaction)
                || !self.scope.contains(where: { transaction.changedParentTypes.keys.contains($0) })
                || (!self.trackedOrigins.contains(transaction.origin as? AnyHashable)
                    
                    // TODO: implement this type of contains...
//                    && (transaction.origin == nil || !self.trackedOrigins.contains(type(of: transaction.origin)))
                    
                   )
            ) {
                return
            }
            let undoing = self.undoing
            let redoing = self.redoing
            let stack = undoing ? self.redoStack : self.undoStack
            if undoing {
                self.stopCapturing() // next undo should not be appended to last stack item
            } else if !redoing {
                // neither undoing nor redoing: delete redoStack
                try self.clear(false, clearRedoStack: true)
            }
            let insertions = YDeleteSet()
            transaction.afterState.forEach({ client, endClock in
                let startClock = transaction.beforeState[client] ?? 0
                let len = endClock - startClock
                if len > 0 {
                    insertions.add(client: client, clock: startClock, length: len)
                }
            })
            let now = Date()
            var didAdd = false
            if self.lastChange > Date.distantPast
                && now.timeIntervalSince(self.lastChange) < self.captureTimeout
                && stack.count > 0
                && !undoing && !redoing {
                // append change to last stack op
                let lastOp = stack[stack.count - 1]
                lastOp.deletions = YDeleteSet.mergeAll([lastOp.deletions, transaction.deleteSet])
                lastOp.insertions = YDeleteSet.mergeAll([lastOp.insertions, insertions])
            } else {
                // create a stack op
                stack.value.append(StackItem(transaction.deleteSet, insertions: insertions))
                didAdd = true
            }
            if !undoing && !redoing {
                self.lastChange = now
            }
            // make sure that deleted structs are not gc'd
            try transaction.deleteSet.iterate(transaction, body: { item in
                if item is YItem && self.scope.contains(where: { type in type.isParentOf(child: (item as! YItem)) }) {
                    (item as? YItem)?.keepRecursive(keep: true)
                }
            })

            let changeEvent = ChangeEvent(
                origin: transaction.origin,
                stackItem: stack[stack.count - 1],
                type: undoing ? .redo : .undo,
                undoStackCleared: nil,
                changedParentTypes: transaction.changedParentTypes
            )

            if didAdd {
                try self.emit(Event.stackItemAdded, changeEvent)
            } else {
                try self.emit(Event.stackItemUpdated, changeEvent)
            }
        }
        self.doc.on(YDocument.On.destroy) {
            try self.destroy()
        }
    }


    public func clearStackItem(_ tr: YTransaction, stackItem: StackItem) throws {
        try stackItem.deletions.iterate(tr) { item in
            if item is YItem && self.scope.contains(where: { type in type.isParentOf(child: (item as! YItem)) }) {
                (item as? YItem)?.keepRecursive(keep: false)
            }
        }
    }


    public func popStackItem(_ stack: Ref<[StackItem]>, eventType: EvnetType) throws -> StackItem? {
        /** Whether a change happened */
        var result: StackItem? = nil
        /** Keep a reference to the transaction so we can fire the event with the changedParentTypes */
        var _tr: YTransaction? = nil
        let doc = self.doc
        let scope = self.scope
        
        try doc.transact(origin: self) { transaction in
            while (stack.count > 0 && result == nil) {
                let store = doc.store
                let stackItem = stack.value.popLast()!
                var itemsToRedo = Set<YItem>()
                var itemsToDelete: [YItem] = []

                var performedChange = false
                try stackItem.insertions.iterate(transaction) { struct_ in
                    var struct_ = struct_
                    if struct_ is YItem {
                        if (struct_ as! YItem).redone != nil {
                            let redone = try followRedone(store: store, id: struct_.id)
                            var item = redone.item, diff = redone.diff
                            if diff > 0 {
                                item = try YStructStore.getItemCleanStart(transaction, id: YID(client: item.id.client, clock: item.id.clock + diff))
                            }
                            struct_ = item
                        }
                        if !struct_.deleted && scope.contains(where: { type in type.isParentOf(child: (struct_ as! YItem)) }) {
                            itemsToDelete.append(struct_ as! YItem)
                        }
                    }
                }
                try stackItem.deletions.iterate(transaction) { struct_ in
                    if (
                        struct_ is YItem &&
                        scope.contains(where: { type in type.isParentOf(child: (struct_ as! YItem)) }) &&
                        // Never redo structs in stackItem.insertions because they were created and deleted in the same capture interval.
                        !stackItem.insertions.isDeleted(struct_.id)
                    ) {
                        itemsToRedo.insert(struct_ as! YItem)
                    }
                }
                try itemsToRedo.forEach({ struct_ in
                    performedChange = try struct_
                        .redo(transaction, redoitems: itemsToRedo, itemsToDelete: stackItem.insertions, ignoreRemoteMapChanges: self.ignoreRemoteMapChanges) != nil || performedChange
                })
                // We want to delete in reverse order so that children are deleted before
                // parents, so we have more information available when items are filtered.
                for i in (0..<itemsToDelete.count).reversed() {
                    let item = itemsToDelete[i]
                    if self.deleteFilter(item) {
                        item.delete(transaction)
                        performedChange = true
                    }
                }
                result = performedChange ? stackItem : nil
            }
            transaction.changed.forEach({ type, subProps in
                // destroy search marker if necessary
                if subProps.contains(nil) && type.serchMarkers != nil {
                    type.serchMarkers!.value.removeAll()
                }
            })
            _tr = transaction
        }
        
        if result != nil {
            let changedParentTypes = _tr!.changedParentTypes
            try self.emit(
                Event.stackItemPopped,
                ChangeEvent(
                    stackItem: result!,
                    type: eventType,
                    changedParentTypes: changedParentTypes
                )
            )
        }
        return result
    }


    public func addToScope(_ ytypes: Object_or_ObjectArray) {
        let ytypes = ytypes.asObjectArray
        ytypes.forEach({ ytype in
            if self.scope.allSatisfy({ $0 !== ytype }) {
                self.scope.value.append(ytype)
            }
        })
    }

    public func addTrackedOrigin(_ origin: AnyHashable) {
        self.trackedOrigins.value.insert(origin)
    }

    public func removeTrackedOrigin(_ origin: AnyHashable?) {
        self.trackedOrigins.value.remove(origin)
    }

    public func clear(_ clearUndoStack: Bool = true, clearRedoStack: Bool = true) throws {
        if (clearUndoStack && self.canUndo()) || (clearRedoStack && self.canRedo()) {
            try self.doc.transact({ tr in
                if clearUndoStack {
                    try self.undoStack.forEach({ item in try self.clearStackItem(tr, stackItem: item) })
                    self.undoStack = .init(value: [])
                }
                if clearRedoStack {
                    try self.redoStack.forEach({ item in try self.clearStackItem(tr, stackItem: item) })
                    self.redoStack = .init(value: [])
                }
                try self.emit(Event.stackCleanred, .init(undoStackCleared: clearUndoStack, redoStackCleared: clearRedoStack))
            })
        }
    }

    public func stopCapturing() {
        self.lastChange = Date.distantPast
    }

    @discardableResult
    public func undo() throws -> StackItem? {
        self.undoing = true
        var res: StackItem?
        defer {
            self.undoing = false
        }
        res = try self.popStackItem(self.undoStack, eventType: .undo)
        return res
    }

    @discardableResult
    public func redo() throws -> StackItem? {
        self.redoing = true
        var res: StackItem?

        defer {
            self.redoing = false
        }
        res = try self.popStackItem(self.redoStack, eventType: .redo)

        return res
    }

    public func canUndo() -> Bool {
        return self.undoStack.count > 0
    }

    public func canRedo() -> Bool {
        return self.redoStack.count > 0
    }

    public override func destroy() throws {
        self.trackedOrigins.value.remove(self)
        self.doc.off(YDocument.On.afterTransaction, self.afterTransactionDisposer)
        try super.destroy()
    }
}


extension YUndoManager {
    public enum EvnetType { case undo, redo }

    public class ChangeEvent {
        public var origin: Any?
        public var stackItem: StackItem
        public var type: EvnetType
        public var undoStackCleared: Bool?
        public var changedParentTypes: [YObject: [YEvent]]
        
        init(origin: Any? = nil, stackItem: StackItem, type: EvnetType, undoStackCleared: Bool? = nil , changedParentTypes: [YObject : [YEvent]]) {
            self.origin = origin
            self.stackItem = stackItem
            self.type = type
            self.undoStackCleared = undoStackCleared
            self.changedParentTypes = changedParentTypes
        }
    }
    
    public class CleanEvent {
        public var undoStackCleared: Bool
        public var redoStackCleared: Bool
        
        init(undoStackCleared: Bool, redoStackCleared: Bool) {
            self.undoStackCleared = undoStackCleared
            self.redoStackCleared = redoStackCleared
        }
    }
    
    public struct Options {
        init(
            captureTimeout: TimeInterval = 500,
            captureTransaction: @escaping ((YTransaction) -> Bool) = {_ in true },
//            deleteFilter: @escaping ((Item) -> Bool) = {_ in true},
            trackedOrigins: Ref<Set<AnyHashable?>> = Ref(value: [nil as UInt8?]),
            ignoreRemoteMapChanges: Bool = false,
            doc: YDocument? = nil
        ) {
            self.captureTimeout = captureTimeout
            self.captureTransaction = captureTransaction
//            self.deleteFilter = deleteFilter
            self.trackedOrigins = trackedOrigins
            self.ignoreRemoteMapChanges = ignoreRemoteMapChanges
            self.doc = doc
        }
        
        var captureTimeout: TimeInterval
        var captureTransaction: ((YTransaction) -> Bool)
        var deleteFilter: ((YItem) -> Bool) = {_ in true }
        var trackedOrigins: Ref<Set<AnyHashable?>>
        var ignoreRemoteMapChanges: Bool
        var doc: YDocument?
    }

    public enum Event {
        public static let stackCleanred = LZObservable.EventName<CleanEvent>("stack-cleared")
        public static let stackItemAdded = LZObservable.EventName<YUndoManager.ChangeEvent>("stack-item-added")
        public static let stackItemPopped = LZObservable.EventName<YUndoManager.ChangeEvent>("stack-item-popped")
        public static let stackItemUpdated = LZObservable.EventName<YUndoManager.ChangeEvent>("stack-item-updated")
    }
}

