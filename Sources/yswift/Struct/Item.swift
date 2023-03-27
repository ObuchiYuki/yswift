//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

extension Item {
    public enum Parent {
        case string(String)
        case id(ID)
        case object(YObject)
        
        var string: String? { if case .string(let parent) = self { return parent }; return nil }
        var id: ID? { if case .id(let parent) = self { return parent }; return nil }
        var object: YObject? { if case .object(let parent) = self { return parent }; return nil }
    }
}

/// Abstract public class that represents any content.
final public class Item: Struct, JSHashable {
    
    // =========================================================================== //
    // MARK: - Properties -

    /// The item that was originally to the left of this item.
    public var origin: ID?

    /// The item that is currently to the left of this item.
    public var left: Struct?

    /// The item that is currently to the right of this item.
    public var right: Struct?

    /// The item that was originally to the right of this item. */
    public var rightOrigin: ID?
    
    public var parent: Parent?
    
    public var parentKey: String?
    
    public var redone: ID?
    
    var content: any Content

    var info: UInt8

    public var marker: Bool {
        get { self.info & 0b0000_1000 > 0 }
        set { if self.marker != newValue { self.info ^= 0b0000_1000 } }
    }

    public var keep: Bool {
        get { self.info & 0b0000_0001 > 0 }
        set { if self.keep != newValue { self.info ^= 0b0000_0001 } }
    }
    
    public override var deleted: Bool {
        get { return self.info & 0b0000_0100 > 0 }
        set { if self.deleted != newValue { self.info ^= 0b0000_0100 } }
    }
    
    public var countable: Bool { self.info & 0b0000_0010 > 0 }
    
    public var next: Item? {
        var item = self.right
        while let uitem = item as? Item, uitem.deleted { item = uitem.right }
        return item as? Item
    }

    public var prev: Item? {
        var item = self.left
        while let uitem = item as? Item, uitem.deleted { item = uitem.left }
        return item as? Item
    }

    /// Computes the last content address of this Item.
    public var lastID: ID {
        if self.length == 1 { return self.id }
        return ID(client: self.id.client, clock: self.id.clock + self.length - 1)
    }

    init(id: ID, left: Struct?, origin: ID?, right: Struct?, rightOrigin: ID?, parent: Parent?, parentSub: String?, content: any Content) {
        self.origin = origin
        self.left = left
        self.right = right
        self.rightOrigin = rightOrigin
        self.parent = parent
        self.parentKey = parentSub
        self.redone = nil
        self.content = content
        self.info = self.content.isCountable ? 0b0000_0010 : 0
        
        super.init(id: id, length: content.count)
    }
    
    // =========================================================================== //
    // MARK: - Methods -
    
    public override func getMissing(_ transaction: Transaction, store: StructStore) throws -> Int? {
        if let origin = self.origin, origin.client != self.id.client, origin.clock >= store.getState(origin.client) {
            return origin.client
        }
        if let rightOrigin = self.rightOrigin, rightOrigin.client != self.id.client, rightOrigin.clock >= store.getState(rightOrigin.client) {
            return rightOrigin.client
        }
        if let parent = self.parent?.id, self.id.client != parent.client, parent.clock >= store.getState(parent.client) {
            return parent.client
        }

        // We have all missing ids, now find the items
        if let origin = self.origin {
            self.left = try store.getItemCleanEnd(transaction, id: origin)
            self.origin = (self.left as? Item)?.lastID
        }
        if let rightOrigin = self.rightOrigin {
            self.right = try StructStore.getItemCleanStart(transaction, id: rightOrigin)
            self.rightOrigin = self.right!.id
        }
        if self.left is GC || self.right is GC {
            self.parent = nil
        }
        // only set parent if this shouldn't be garbage collected
        if self.parent == nil {
            if let leftItem = self.left as? Item {
                self.parent = leftItem.parent
                self.parentKey = leftItem.parentKey
            }
            if let rightItem = self.right as? Item {
                self.parent = rightItem.parent
                self.parentKey = rightItem.parentKey
            }
        } else if let parent = self.parent?.id {
            let parentItem = try store.find(parent)
            if let content = (parentItem as? Item)?.content as? TypeContent {
                self.parent = .object(content.type)
            } else {
                self.parent = nil
            }
        }
        return nil
    }

    public override func integrate(transaction: Transaction, offset: Int) throws {
        if offset > 0 {
            self.id.clock += offset
            self.left = try transaction.doc.store.getItemCleanEnd(
                transaction,
                id: ID(client: self.id.client, clock: self.id.clock - 1)
            )
            self.origin = (self.left as? Item)?.lastID
            self.content = self.content.splice(offset)
            self.length -= offset
        }

        guard let parent = self.parent?.object else {
            try GC(id: self.id, length: self.length).integrate(transaction: transaction, offset: 0)
            return
        }
        
        let hasLeft = self.left == nil && (self.right == nil || (self.right as? Item)?.left != nil)
        let hasRight = (self.left != nil && (self.left as? Item)?.right !== self.right)

        if hasLeft || hasRight {
            var left = self.left as? Item

            var item: Item?

            if let rightItem = left?.right as? Item {
                item = rightItem
            } else {
                if let parentKey = self.parentKey {
                    item = parent.storage[parentKey]
                    while let left = item?.left as? Item { item = left }
                } else {
                    item = parent._start
                }
            }
            
            var conflictingItems = Set<Item>()
            var itemsBeforeOrigin = Set<Item>()
            
            while let uitem = item, uitem !== self.right {
                itemsBeforeOrigin.insert(uitem)
                conflictingItems.insert(uitem)
                if self.origin == uitem.origin {
                    // case 1
                    if uitem.id.client < self.id.client {
                        left = uitem
                        conflictingItems.removeAll()
                    } else if self.rightOrigin == uitem.rightOrigin {
                        break
                    }
                } else if let origin = uitem.origin, try itemsBeforeOrigin.contains(transaction.doc.store.getItem(origin)) {
                    // case 2
                    if !conflictingItems.contains(try transaction.doc.store.getItem(origin)) {
                        left = uitem
                        conflictingItems.removeAll()
                    }
                } else {
                    break
                }
                item = uitem.right as? Item
            }
            self.left = left
        }
        
        if let left = self.left as? Item {
            let right = left.right
            self.right = right
            left.right = self
        } else {
            var right: Item?
            
            if let parentKey = self.parentKey {
                right = parent.storage[parentKey]
                while let left = right?.left as? Item { right = left }
            } else {
                right = parent._start
                parent._start = self
            }
            
            self.right = right
        }
        
        if let right = self.right as? Item {
            right.left = self
        } else if let parentKey = self.parentKey {
        
            // set as current parent value if right == nil and this is parentSub
            parent.storage[parentKey] = self
            
            if let left = self.left as? Item {
                // this is the current attribute value of parent. delete right
                left.delete(transaction)
            }
        }
        // adjust length of parent
        if self.parentKey == nil && self.countable && !self.deleted {
            parent._length += self.length
        }
        
        try transaction.doc.store.addStruct(self)
        
        try self.content.integrate(with: self, transaction)
        
        // add parent to transaction.changed
        transaction.addChangedType(parent, parentSub: self.parentKey)
        
        // delete if parent is deleted or if this is not the current attribute value of parent
        if let parentItem = parent.item, parentItem.deleted { self.delete(transaction) }
        if self.parentKey != nil, self.right != nil { self.delete(transaction) }
    }
    
    public override func merge(with right: Struct) -> Bool {
        guard let right = right as? Item else { return false }
        guard right.origin == self.lastID,
              self.right === right,
              self.rightOrigin == right.rightOrigin,
              self.id.client == right.id.client,
              self.id.clock + self.length == right.id.clock,
              self.deleted == right.deleted,
              self.redone == nil,
              right.redone == nil,
              type(of: self.content) == type(of: right.content),
              self.content.merge(with: right.content),
              let parent = self.parent?.object
        else { return false }
    
        for marker in parent.serchMarkers ?? [] where marker.item === right {
            marker.item = self
            if !self.deleted && self.countable {
                marker.index -= self.length
            }
        }
        
        if right.keep { self.keep = true }
        self.right = right.right
        
        if let right = self.right as? Item { right.left = self }
        self.length += right.length
        
        return true
    }

    public override func encode(into encoder: YUpdateEncoder, offset: Int) throws {
        let origin = offset > 0 ? ID(client: self.id.client, clock: self.id.clock + offset - 1) : self.origin
        let rightOrigin = self.rightOrigin
        let parentSub = self.parentKey
        
        let info: UInt8 =
            (self.content.typeid    & 0b0001_1111) |
            (origin == nil      ? 0 : 0b1000_0000) | // origin is defined
            (rightOrigin == nil ? 0 : 0b0100_0000) | // right origin is defined
            (parentSub == nil   ? 0 : 0b0010_0000)   // parentSub is non-nil
        
        encoder.writeInfo(info)
        
        if let origin = origin { encoder.writeLeftID(origin) }
        if let rightOrigin = rightOrigin { encoder.writeRightID(rightOrigin) }
        
        if origin == nil && rightOrigin == nil {
            switch self.parent {
            case .object(let parent):
                let parentItem = parent.item
                if parentItem == nil {
                    let ykey = try findRootTypeKey(type: parent)
                    encoder.writeParentInfo(true)
                    encoder.writeString(ykey)
                } else {
                    encoder.writeParentInfo(false)
                    encoder.writeLeftID(parentItem!.id)
                }
            case .id(let parent):
                encoder.writeParentInfo(false)
                encoder.writeLeftID(parent)
            case .string(let parent): // write parentYKey
                encoder.writeParentInfo(true)
                encoder.writeString(parent)
            case .none:
                throw YSwiftError.unexpectedCase
            }
            
            if parentSub != nil { encoder.writeString(parentSub!) }
        }
        
        try self.content.encode(into: encoder, offset: offset)
    }
}

// =========================================================================== //
// MARK: - Item Methods -

extension Item {
    /** Mark this Item as deleted. */
    public func delete(_ transaction: Transaction) {
        guard !self.deleted, let parent = self.parent?.object else { return }
        
        // adjust the length of parent
        if self.countable && self.parentKey == nil {
            parent._length -= self.length
        }
        
        self.deleted = true
        transaction.deleteSet.add(client: self.id.client, clock: self.id.clock, length: self.length)
        transaction.addChangedType(parent, parentSub: self.parentKey)
        self.content.delete(transaction)
    }

    public func gc(_ store: StructStore, parentGC: Bool) throws {
        if !self.deleted { throw YSwiftError.unexpectedCase }
        
        try self.content.gc(store)
        
        if parentGC {
            try store.replaceStruct(self, newStruct: GC(id: self.id, length: self.length))
        } else {
            self.content = DeletedContent(self.length)
        }
    }
    
    func keepRecursive(keep: Bool) {
        var item: Item? = self
        while let uitem = item, uitem.keep != keep {
            item!.keep = keep
            item = uitem.parent?.object?.item
        }
    }

    func isVisible(_ snapshot: Snapshot?) -> Bool {
        guard let snapshot = snapshot else {
            return !self.deleted
        }
        guard let sclock = snapshot.stateVectors[self.id.client], sclock > self.id.clock, !snapshot.deleteSet.isDeleted(self.id) else {
            return false
        }
        return true
    }

    /// Split leftItem into two items; this -> leftItem
    public func split(_ transaction: Transaction, diff: Int) -> Item {
        let client = self.id.client, clock = self.id.clock
        
        let rightItem = Item(
            id: ID(client: client, clock: clock + diff),
            left: self,
            origin: ID(client: client, clock: clock + diff - 1),
            right: self.right,
            rightOrigin: self.rightOrigin,
            parent: self.parent,
            parentSub: self.parentKey,
            content: self.content.splice(diff)
        )
        if self.deleted { rightItem.deleted = true }
        if self.keep { rightItem.keep = true }
        
        if let redone = self.redone { rightItem.redone = ID(client: redone.client, clock: redone.clock + diff) }
        
        self.right = rightItem
        if let rightRightItem = rightItem.right as? Item { rightRightItem.left = rightItem }
        
        transaction._mergeStructs.value.append(rightItem)
        
        if let parentSub = rightItem.parentKey, rightItem.right == nil {
            rightItem.parent?.object?.storage[parentSub] = rightItem
        }
        self.length = diff
        return rightItem
    }

    public func redo(_ transaction: Transaction, redoitems: Set<Item>, itemsToDelete: DeleteSet, ignoreRemoteMapChanges: Bool) throws -> Item? {
        if let redone = self.redone { return try StructStore.getItemCleanStart(transaction, id: redone) }
        
        let doc = transaction.doc
        let store = doc.store
        let ownClientID = doc.clientID
        
        var parentItem = self.parent!.object!.item
        var left: Struct? = nil
        var right: Struct? = nil

        if let uparentItem = parentItem, uparentItem.deleted {
            
            if uparentItem.redone == nil {
                if !redoitems.contains(uparentItem) { return nil }
                let redo = try uparentItem
                    .redo(transaction, redoitems: redoitems, itemsToDelete: itemsToDelete, ignoreRemoteMapChanges: ignoreRemoteMapChanges)
                if redo == nil { return nil }
            }
            
            while let redone = uparentItem.redone {
                parentItem = try StructStore.getItemCleanStart(transaction, id: redone)
            }
            
        }
        
        let parentType: YObject
        
        if let parentContent = parentItem?.content as? TypeContent {
            parentType = parentContent.type
        } else if let parentObject = self.parent?.object {
            parentType = parentObject
        } else {
            return nil
        }
        
        if self.parentKey == nil {
            left = self.left
            right = self
            
            while let uleft = left as? Item {
                var leftTrace: Item? = uleft
                
                while let uleftTrace = leftTrace, uleftTrace.parent?.object?.item !== parentItem {
                    guard let redone = uleftTrace.redone else { leftTrace = nil; break }
                    leftTrace = try StructStore.getItemCleanStart(transaction, id: redone)
                }
                if let uleftTrace = leftTrace, uleftTrace.parent?.object?.item === parentItem {
                    left = uleftTrace; break
                }
                
                left = uleft.left
            }
            
            while let uright = right as? Item {
                var rightTrace: Item? = uright
                
                while let urightTrace = rightTrace, urightTrace.parent?.object?.item !== parentItem {
                    if let redone = urightTrace.redone {
                        rightTrace = try StructStore.getItemCleanStart(transaction, id: redone)
                    } else {
                        rightTrace = nil
                        break
                    }
                }
                if let urightTrace = rightTrace, urightTrace.parent?.object?.item === parentItem {
                    right = urightTrace
                    break
                }
                right = uright.right
            }
            
        } else {
            right = nil
            if self.right != nil && !ignoreRemoteMapChanges {
                left = self
                
                while let uleft = left as? Item, let leftRight = uleft.right, itemsToDelete.isDeleted(leftRight.id) {
                    left = uleft.right
                }
                while let redone = (left as? Item)?.redone {
                    left = try StructStore.getItemCleanStart(transaction, id: redone)
                }
                if let uleft = left as? Item, uleft.right != nil {
                    return nil
                }
            } else if let parentKey = self.parentKey {
                left = parentType.storage[parentKey]
            } else {
                assertionFailure()
            }
        }
        let nextClock = store.getState(ownClientID)
        let nextId = ID(client: ownClientID, clock: nextClock)
        let redoneItem = Item(
            id: nextId,
            left: left,
            origin: (left as? Item)?.lastID,
            right: right,
            rightOrigin: right?.id,
            parent: .object(parentType),
            parentSub: self.parentKey,
            content: self.content.copy()
        )
        self.redone = nextId
        redoneItem.keepRecursive(keep: true)
        try redoneItem.integrate(transaction: transaction, offset: 0)
        return redoneItem
    }
}
