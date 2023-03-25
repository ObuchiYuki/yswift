//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

public protocol Object_or_ID_or_String: Equatable {}
extension YCObject: Object_or_ID_or_String {}
extension ID: Object_or_ID_or_String {}
extension String: Object_or_ID_or_String {}

/// Abstract public class that represents any content.
final public class Item: Struct, JSHashable {

    /// The item that was originally to the left of this item.
    public var origin: ID?

    /// The item that is currently to the left of this item.
    public var left: Struct?

    /// The item that is currently to the right of this item.
    public var right: Struct?

    /// The item that was originally to the right of this item. */
    public var rightOrigin: ID?
    
    public var parent: (any Object_or_ID_or_String)?
    
    public var parentSub: String?
    
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

    init( id: ID, left: Struct?, origin: ID?, right: Struct?, rightOrigin: ID?, parent: (any Object_or_ID_or_String)?, parentSub: String?, content: any Content) {
        self.origin = origin
        self.left = left
        self.right = right
        self.rightOrigin = rightOrigin
        self.parent = parent
        self.parentSub = parentSub
        self.redone = nil
        self.content = content
        self.info = self.content.isCountable ? 0b0000_0010 : 0
        
        super.init(id: id, length: content.count)
    }
    
    // =========================================================================== //
    // MARK: - Methods -

    func keepRecursive(keep: Bool) {
        var item: Item? = self
        while item != nil && item!.keep != keep {
           item!.keep = keep
           item = (item!.parent as! YCObject)._item
        }
    }

    func isVisible(_ snapshot: Snapshot?) -> Bool {
        guard let snapshot = snapshot else {
            return !self.deleted
        }
        guard let sclock = snapshot.sv[self.id.client], sclock > self.id.clock, !snapshot.ds.isDeleted(self.id) else {
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
            parentSub: self.parentSub,
            content: self.content.splice(diff)
        )
        if self.deleted { rightItem.deleted = true }
        if self.keep { rightItem.keep = true }
        
        if let redone = self.redone { rightItem.redone = ID(client: redone.client, clock: redone.clock + diff) }
        
        self.right = rightItem
        if let rightRightItem = rightItem.right as? Item { rightRightItem.left = rightItem }
        
        transaction._mergeStructs.value.append(rightItem)
        
        if let parentSub = rightItem.parentSub, rightItem.right == nil {
            (rightItem.parent as! YCObject).storage[parentSub] = rightItem
        }
        self.length = diff
        return rightItem
    }

    public func redo(_ transaction: Transaction, redoitems: Set<Item>, itemsToDelete: DeleteSet, ignoreRemoteMapChanges: Bool) throws -> Item? {
        if let redone = self.redone { return try StructStore.getItemCleanStart(transaction, id: redone) }
        
        let doc = transaction.doc
        let store = doc.store
        let ownClientID = doc.clientID
        
        var parentItem = (self.parent as! YCObject)._item
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
        
        let parentType: YCObject
        
        if let parentItem = parentItem, let parentContent = parentItem.content as? TypeContent {
            parentType = parentContent.type
        } else if let parentObject = self.parent as? YCObject {
            parentType = parentObject
        } else {
            return nil
        }
        
        if self.parentSub == nil {
            left = self.left
            right = self
            
            while let uleft = left as? Item {
                var leftTrace: Item? = uleft
                
                while let uleftTrace = leftTrace, (uleftTrace.parent as? YCObject)?._item !== parentItem {
                    guard let redone = uleftTrace.redone else { leftTrace = nil; break }
                    leftTrace = try StructStore.getItemCleanStart(transaction, id: redone)
                }
                if let uleftTrace = leftTrace, (uleftTrace.parent as? YCObject)?._item === parentItem {
                    left = uleftTrace; break
                }
                
                left = uleft.left
            }
            
            while let uright = right as? Item {
                var rightTrace: Item? = uright
                
                while let urightTrace = rightTrace, (urightTrace.parent as? YCObject)?._item !== parentItem {
                    if let redone = urightTrace.redone {
                        rightTrace = try StructStore.getItemCleanStart(transaction, id: redone)
                    } else {
                        rightTrace = nil
                        break
                    }
                }
                if let urightTrace = rightTrace, (urightTrace.parent as? YCObject)?._item === parentItem {
                    right = urightTrace
                    break
                }
                right = uright.right
            }
            
        } else {
            right = nil
            if self.right != nil && !ignoreRemoteMapChanges {
                left = self
                // Iterate right while right is in itemsToDelete
                // If it is intended to delete right while item is redone, we can expect that item should replace right.
                while left != nil && left is Item && (left as! Item).right != nil && itemsToDelete.isDeleted((left as! Item).right!.id) {
                    left = (left as! Item).right
                }
                
                while left != nil && left is Item && (left as! Item).redone != nil {
                    left = try StructStore.getItemCleanStart(transaction, id: (left as! Item).redone!)
                }
                if left != nil && left is Item && (left as! Item).right != nil {
                    return nil
                }
            } else {
                left = parentType.storage[self.parentSub!]
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
            parent: parentType,
            parentSub: self.parentSub,
            content: self.content.copy()
        )
        self.redone = nextId
        redoneItem.keepRecursive(keep: true)
        try redoneItem.integrate(transaction: transaction, offset: 0)
        return redoneItem
    }
    
    /** Return the creator clientID of the missing op or define missing items and return nil. */
    public override func getMissing(_ transaction: Transaction, store: StructStore) throws -> Int? {
        if self.origin != nil && self.origin!.client != self.id.client && self.origin!.clock >= store.getState(self.origin!.client) {
            return self.origin!.client
        }
        if self.rightOrigin != nil && self.rightOrigin!.client != self.id.client && self.rightOrigin!.clock >= store.getState(self.rightOrigin!.client) {
            return self.rightOrigin!.client
        }
        if self.parent != nil && self.parent is ID && self.id.client != (self.parent as! ID).client && (self.parent as! ID).clock >= store.getState((self.parent as! ID).client) {
            return (self.parent as! ID).client
        }

        // We have all missing ids, now find the items
        if self.origin != nil {
            self.left = try store.getItemCleanEnd(transaction, id: self.origin!)
            self.origin = (self.left as? Item)?.lastID
        }
        if self.rightOrigin != nil {
            self.right = try StructStore.getItemCleanStart(transaction, id: self.rightOrigin!)
            self.rightOrigin = self.right!.id
        }
        if (self.left != nil && self.left is GC) || (self.right != nil && self.right is GC) {
            self.parent = nil
        }
        // only set parent if this shouldn't be garbage collected
        if self.parent == nil {
            if self.left != nil && self.left is Item {
                self.parent = (self.left as! Item).parent
                self.parentSub = (self.left as! Item).parentSub
            }
            if self.right != nil && self.right is Item {
                self.parent = (self.right as! Item).parent
                self.parentSub = (self.right as! Item).parentSub
            }
        } else if self.parent is ID {
            let parentItem = try store.find(self.parent as! ID)
            if parentItem is GC {
                self.parent = nil
            } else {
                self.parent = ((parentItem as! Item).content as? TypeContent)?.type
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


        if self.parent != nil {
            if (self.left == nil && (self.right == nil || (self.right as? Item)?.left != nil))
                || (self.left != nil && (self.left as? Item)?.right !== self.right)
            {
                var left = self.left as? Item

                var item: Item?
                // set o to the first conflicting item
                if left != nil {
                    item = (left!.right as! Item)
                } else if self.parentSub != nil {
                    item = (self.parent as! YCObject).storage[self.parentSub!]
                    while(item != nil && item!.left != nil) {
                        item = (item!.left as! Item)
                    }
                } else {
                    item = (self.parent as! YCObject)._start
                }
                
                var conflictingItems = Set<Item>()
                var itemsBeforeOrigin = Set<Item>()
                // Let c in conflictingItems, b in itemsBeforeOrigin
                // ***{origin}bbbb{this}{c,b}{c,b}{o}***
                // Note that conflictingItems is a subset of itemsBeforeOrigin
                while(item != nil && item !== self.right) {
                    itemsBeforeOrigin.insert(item!)
                    conflictingItems.insert(item!)
                    if self.origin == item!.origin {
                        // case 1
                        if item!.id.client < self.id.client {
                            left = item!
                            conflictingItems.removeAll()
                        } else if self.rightOrigin == item!.rightOrigin {
                            // this and o are conflicting and point to the same integration points. The id decides which item comes first.
                            // Since this is to the left of o, we can break here
                            break
                        } // else, o might be integrated before an item that this conflicts with. If so, we will find it in the next iterations
                    } else if try item!.origin != nil && itemsBeforeOrigin.contains(transaction.doc.store.getItem(item!.origin!)) {
                        // use getItem instead of getItemCleanEnd because we don't want / need to split items.
                        // case 2
                        if !conflictingItems.contains(try transaction.doc.store.getItem(item!.origin!)) {
                            left = item!
                            conflictingItems.removeAll()
                        }
                    } else {
                        break
                    }
                    item = (item!.right as? Item)
                }
                self.left = left
            }
            
            if self.left != nil && self.left is Item {
                let right = (self.left as! Item).right
                self.right = right
                (self.left as! Item).right = self
            } else {
                var r: Item?
                if self.parentSub != nil {
                    r = (self.parent as! YCObject).storage[parentSub!]
                    while r != nil && r!.left != nil {
                        r = (r!.left as! Item)
                    }
                } else {
                    r = (self.parent as! YCObject)._start
                    (self.parent as! YCObject)._start = self
                }
                self.right = r
            }
            if self.right != nil {
                (self.right as! Item).left = self
            } else if self.parentSub != nil {
                // set as current parent value if right == nil and this is parentSub
                (self.parent as! YCObject).storage[self.parentSub!] = self
                if self.left != nil {
                    // this is the current attribute value of parent. delete right
                    (self.left as! Item).delete(transaction)
                }
            }
            // adjust length of parent
            if self.parentSub == nil && self.countable && !self.deleted {
                (self.parent as! YCObject)._length += self.length
            }
            
            
            try transaction.doc.store.addStruct(self)
            
            try self.content.integrate(with: self, transaction)
            
            // add parent to transaction.changed
            transaction.addChangedType((self.parent as! YCObject), parentSub: self.parentSub)
            if ((self.parent as! YCObject)._item != nil && (self.parent as! YCObject)._item!.deleted)
                || (self.parentSub != nil && self.right != nil)
            {
                // delete if parent is deleted or if this is not the current attribute value of parent
                self.delete(transaction)
            }
        } else {
            // parent is not defined. Integrate GC struct instead
            try GC(id: self.id, length: self.length).integrate(transaction: transaction, offset: 0)
        }
        
    }

    public var next: Item? {
        var n = self.right
        while (n != nil && n!.deleted) { n = (n as! Item).right }
        return (n as! Item)
    }

    public var prev: Item? {
        var n = self.left
        while(n != nil && n!.deleted) { n = (n as! Item).left }
        return (n as! Item)
    }

    /**
     * Computes the last content address of this Item.
     */
    public var lastID: ID {
        // allocating ids is pretty costly because of the amount of ids created, so we try to reuse whenever possible
        return self.length == 1 ? self.id : ID(
            client: self.id.client,
            clock: self.id.clock + self.length - 1
        )
    }
    
    public override func merge(with right: Struct) -> Bool {
        guard let right = right as? Item else {
            return false
        }
        
        if (
            type(of: self) == type(of: right) &&
            right.origin == self.lastID &&
            self.right === right &&
            self.rightOrigin == right.rightOrigin &&
            self.id.client == right.id.client &&
            self.id.clock + self.length == right.id.clock &&
            self.deleted == right.deleted &&
            self.redone == nil &&
            right.redone == nil &&
            type(of: self.content) == type(of: right.content) &&
            self.content.merge(with: right.content)
        ) {
            let searchMarker = (self.parent as! YCObject)._searchMarker
            if searchMarker != nil {
                searchMarker!.forEach({ marker in
                    if marker.item == right {
                        marker.item = self
                        if !self.deleted && self.countable { marker.index -= self.length }
                    }
                })
            }
            
            if right.keep { self.keep = true }
            self.right = right.right
            if self.right != nil { (self.right as? Item)?.left = self }
            self.length += right.length
            return true
        }
        return false
    }

    /** Mark this Item as deleted. */
    public func delete(_ transaction: Transaction) {
        if !self.deleted {
            let parent = self.parent as! YCObject
            // adjust the length of parent
            if self.countable && self.parentSub == nil {
                parent._length -= self.length
            }
            self.deleted = true
            transaction.deleteSet.add(client: self.id.client, clock: self.id.clock, length: self.length)
            transaction.addChangedType(parent, parentSub: self.parentSub)
            self.content.delete(transaction)
        }
    }

    public func gc(_ store: StructStore, parentGCd: Bool) throws {
        if !self.deleted {
            throw YSwiftError.unexpectedCase
        }
        try self.content.gc(store)
        if parentGCd {
            try store.replaceStruct(self, newStruct: GC(id: self.id, length: self.length))
        } else {
            self.content = DeletedContent(self.length)
        }
    }

    /**
     * Transform the properties of this type to binary and write it to an
     * BinaryEncoder.
     *
     * This is called when this Item is sent to a remote peer.
     */
    public override func write(encoder: UpdateEncoder, offset: Int) throws {
        let origin = offset > 0 ? ID(client: self.id.client, clock: self.id.clock + offset - 1) : self.origin
        let rightOrigin = self.rightOrigin
        let parentSub = self.parentSub
        let info: UInt8 = (self.content.typeid & 0b0001_1111) |
            (origin == nil ? 0 : 0b1000_0000) | // origin is defined
            (rightOrigin == nil ? 0 : 0b0100_0000) | // right origin is defined
            (parentSub == nil ? 0 : 0b0010_0000) // parentSub is non-nil
        
        encoder.writeInfo(info)
        if origin !== nil {
            encoder.writeLeftID(origin!)
        }
        if rightOrigin !== nil {
            encoder.writeRightID(rightOrigin!)
        }
        if origin == nil && rightOrigin == nil {
            if self.parent is YCObject {
                let parentItem = (self.parent as! YCObject)._item
                if parentItem == nil {
                    // parent type on y._map
                    // find the correct key
                    let ykey = try findRootTypeKey(type: parent as! YCObject)
                    encoder.writeParentInfo(true) // write parentYKey
                    encoder.writeString(ykey)
                } else {
                    encoder.writeParentInfo(false) // write parent id
                    encoder.writeLeftID(parentItem!.id)
                }
            } else if self.parent! is String { // this edge case was added by differential updates
                encoder.writeParentInfo(true) // write parentYKey
                encoder.writeString(parent as! String)
            } else if self.parent! is ID {
                encoder.writeParentInfo(false) // write parent id
                encoder.writeLeftID(parent as! ID)
            } else {
                
                throw YSwiftError.unexpectedCase
            }
            if parentSub != nil {
                encoder.writeString(parentSub!)
            }
        }
        
        try self.content.encode(into: encoder, offset: offset)
    }
}
