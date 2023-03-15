//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import lib0

public protocol ItemParent: AnyObject {
    var client: UInt { get }
    var clock: UInt { get }
}
extension AbstractType: ItemParent {}
extension ID: ItemParent {}

/// Abstract public class that represents any content.
public class Item: Struct, JSHashable {
    // =========================================================================== //
    // MARK: - Property -

    /// The item that was originally to the left of this item.
    public var origin: ID?

    /// The item that is currently to the left of this item.
    public var left: Item?

    /// The item that is currently to the right of this item.
    public var right: Item?

    /// The item that was originally to the right of this item. */
    public var rightOrigin: ID?
    
    public var parent: ItemParent?
    
    public var parentSub: String?
    
    public var redone: ID?
    
    public var content: any Content

    public var info: UInt8

    public var marker: Bool {
        set {
            if (self.info & 0b0000_1000 > 0) == newValue { return }
            self.info ^= 0b0000_1000
        }
        get { self.info & 0b0000_1000 > 0 }
    }

    public var keep: Bool {
        get { self.info & 0b0000_0001 > 0 }
        set {
            if self.keep == newValue { return }
            self.info ^= 0b0000_0001
        }
    }

    public var countable: Bool {
        return self.info & 0b0000_0010 > 0
    }

    /** Whether this item was deleted or not. */
    public override var deleted: Bool {
        get { return self.info & 0b0000_0100 > 0 }
        set {
            if self.deleted == newValue { return }
            self.info ^= 0b0000_0100
        }
    }


    /** parent is a type if integrated, is nil if it is possible to copy parent from left or right, is ID before integration to search for it.*/
    init(
        id: ID,
        left: Item?,
        origin: ID?,
        right: Item?,
        rightOrigin: ID?,
        parent: ItemParent?,
        parentSub: String?,
        content: any Content
    ) {
        super.init(id: id, length: content.getLength())
        
        self.origin = origin
        self.left = left
        self.right = right
        self.rightOrigin = rightOrigin
        self.parent = parent
        self.parentSub = parentSub
        self.redone = nil
        self.content = content
        self.info = self.content.isCountable() ? 0b0000_0010 : 0
    }
    
    // =========================================================================== //
    // MARK: - Methods -

    static public func keepRecursive(_ item: Item?, keep: Bool) {
        while var item = item, item.keep != keep {
           item.keep = keep
           item = (item.parent as! AbstractType)._item
        }
    }
    

    public func isVisible(_ snapshot: Snapshot?) -> Bool {
        guard let snapshot = snapshot else {
            return !self.deleted
        }
        return snapshot.sv.has(self.id.client)
            && (snapshot.sv[self.id.client] ?? 0) > self.id.clock
            && !snapshot.ds.isDeleted(self.id)
    }

    public func markDeleted() { self.info |= 0b0000_0100 }

    /// Split leftItem into two items; this -> leftItem
    public func split(_ transaction: Transaction, diff: UInt) -> Item {
        let client = self.id.client, clock = self.id.clock
        
        let rightItem = Item(
            ID(client: client, clock: clock + diff),
            self,
            ID(client: client, clock: clock + diff - 1),
            self.right,
            self.rightOrigin,
            self.parent,
            self.parentSub,
            self.content.splice(Int(diff))
        )
        if self.deleted {
            rightItem.markDeleted()
        }
        if self.keep {
            rightItem.keep = true
        }
        if let redone = self.redone {
            rightItem.redone = ID(client: redone.client, clock: redone.clock + diff)
        }
        self.right = rightItem
        // update right
        if rightItem.right !== nil {
            rightItem.right.left = rightItem
        }
        // right is more specific.
        transaction._mergeStructs.push(rightItem)
        // update parent._map
        if rightItem.parentSub !== nil && rightItem.right == nil {
            (rightItem.parent as AbstractType)._map.set(rightItem.parentSub, rightItem)
        }
        self.length = diff
        return rightItem
    }


    /** Redoes the effect of this operation. */
    public func redo(_ transaction: Transaction, redoitems: Set<Item>, itemsToDelete: DeleteSet, ignoreRemoteMapChanges: Bool) -> Item? {
        let doc = transaction.doc
        let store = doc.store
        let ownClientID = doc.clientID
        let redone = self.redone
        if redone !== nil {
            return StructStore.getItemCleanStart(transaction, redone)
        }
        var parentItem = (self.parent as AbstractType)._item
        var left: Item? = nil
        var right: Item? = nil
        // make sure that parent is redone
        if parentItem !== nil && parentItem.deleted == true {
            // try to undo parent if it will be undone anyway
            if parentItem.redone == nil && (redoitems[parentItem] == nil || parentItem.redo(transaction, redoitems, itemsToDelete, ignoreRemoteMapChanges) == nil) {
                return nil
            }
            while(parentItem.redone !== nil) {
                parentItem = StructStore.getItemCleanStart(transaction, parentItem.redone)
            }
        }
        let parentType = parentItem == nil ? (self.parent as! AbstractType) : (parentItem.content as! ContentType).type

        if self.parentSub == nil {
            // Is an array item. Insert at the old position
            left = self.left
            right = self
            // find next cloned_redo items
            while let nonnilLeft = left {

                var leftTrace = nonnilLeft
                // trace redone until parent matches
                while(leftTrace !== nil && (leftTrace.parent as AbstractType)._item !== parentItem) {
                    leftTrace = leftTrace.redone == nil ? nil : StructStore.getItemCleanStart(transaction, leftTrace.redone)
                }
                if leftTrace !== nil && (leftTrace.parent as AbstractType)._item == parentItem {
                    left = leftTrace
                    break
                }
                left = nonnilLeft.left
            }
            
            while let nonnilRight = right {

                var rightTrace = nonnilRight
                // trace redone until parent matches
                while(rightTrace !== nil && (rightTrace.parent as AbstractType)._item !== parentItem) {
                    rightTrace = rightTrace.redone == nil ? nil : StructStore.getItemCleanStart(transaction, rightTrace.redone)
                }
                if rightTrace !== nil && (rightTrace.parent as AbstractType)._item == parentItem {
                    right = rightTrace
                    break
                }
                right = nonnilRight.right
            }
        } else {
            right = nil
            if self.right != nil && !ignoreRemoteMapChanges {
                left = self
                // Iterate right while right is in itemsToDelete
                // If it is intended to delete right while item is redone, we can expect that item should replace right.
                while left != nil && left!.right != nil && itemsToDelete.isDeleted(left!.right!.id) {
                    left = left!.right
                }
                
                while left != nil && left!.redone != nil {
                    left = StructStore.getItemCleanStart(transaction, left!.redone!)
                }
                if left != nil && left!.right != nil {
                    return nil
                }
            } else {
                left = parentType._map.get(self.parentSub) ?? nil
            }
        }
        let nextClock = store.getState(ownClientID)
        let nextId = ID(client: ownClientID, clock: nextClock)
        let redoneItem = Item(
            nextId,
            left,
            left != nil,
//            left && left.lastID,
            right,
            right != nil,
//            right && right.id,
            parentType,
            self.parentSub,
            self.content.copy()
        )
        self.redone = nextId
        Item.keepRecursive(redoneItem, keep: true)
        redoneItem.integrate(transaction, 0)
        return redoneItem
    }
    
    /** Return the creator clientID of the missing op or define missing items and return nil. */
    public func getMissing(_ transaction: Transaction, store: StructStore) -> UInt? {
        if self.origin != nil && self.origin!.client != self.id.client && self.origin!.clock >= store.getState(self.origin!.client) {
            return self.origin!.client
        }
        if self.rightOrigin != nil && self.rightOrigin!.client != self.id.client && self.rightOrigin!.clock >= store.getState(self.rightOrigin!.client) {
            return self.rightOrigin!.client
        }
        if self.parent != nil && self.parent is ID && self.id.client != self.parent!.client && self.parent!.clock >= store.getState(self.parent!.client) {
            return self.parent!.client
        }

        // We have all missing ids, now find the items
        if self.origin != nil {
            self.left = store.getItemCleanEnd(transaction, self.origin!)
            self.origin = self.left!.lastID
        }
        if self.rightOrigin != nil {
            self.right = StructStore.getItemCleanStart(transaction, self.rightOrigin!)
            self.rightOrigin = self.right!.id
        }
        if (self.left && self.left is GC) || (self.right && self.right is GC) {
            self.parent = nil
        }
        // only set parent if this shouldn't be garbage collected
        if self.parent == nil {
            if self.left != nil && type(of: self.left) == Item.self {
                self.parent = self.left!.parent
                self.parentSub = self.left!.parentSub
            }
            if self.right != nil && type(of: self.right) == Item.self {
                self.parent = self.right!.parent
                self.parentSub = self.right!.parentSub
            }
        } else if self.parent is ID {
            let parentItem = store.getItem(self.parent)
            if parentItem is GC {
                self.parent = nil
            } else {
                self.parent = (parentItem.content as ContentType).type
            }
        }
        return nil
    }

    public func integrate(_ transaction: Transaction, offset: UInt) {
        if offset > 0 {
            self.id.clock += offset
            self.left = transaction.doc.store.getItemCleanEnd(
                transaction,
                ID(client: self.id.client, clock: self.id.clock - 1)
            )
            self.origin = self.left!.lastID
            self.content = self.content.splice(offset)
            self.length -= offset
        }

        if self.parent != nil {
            if (self.left == nil && (self.right == nil || self.right?.left != nil))
                || (self.left != nil && self.left?.right !== self.right)
            {
                var left: Item? = self.left

                var item: Item?
                // set o to the first conflicting item
                if left != nil {
                    item = left!.right
                } else if self.parentSub != nil {
                    item = (self.parent as AbstractType)._map[self.parentSub] || nil
                    while(item !== nil && item!.left !== nil) {
                        item = item!.left
                    }
                } else {
                    item = (self.parent as AbstractType)._start
                }
                
                var conflictingItems = Set<Item>()
                var itemsBeforeOrigin = Set<Item>()
                // Let c in conflictingItems, b in itemsBeforeOrigin
                // ***{origin}bbbb{this}{c,b}{c,b}{o}***
                // Note that conflictingItems is a subset of itemsBeforeOrigin
                while(item !== nil && item !== self.right) {
                    itemsBeforeOrigin.insert(item)
                    conflictingItems.insert(item)
                    if self.origin == item!.origin {
                        // case 1
                        if item!.id.client < self.id.client {
                            left = item
                            conflictingItems.removeAll()
                        } else if self.rightOrigin == item!.rightOrigin {
                            // this and o are conflicting and point to the same integration points. The id decides which item comes first.
                            // Since this is to the left of o, we can break here
                            break
                        } // else, o might be integrated before an item that this conflicts with. If so, we will find it in the next iterations
                    } else if item!.origin !== nil && itemsBeforeOrigin[transaction.doc.store.getItem(item!.origin)] != nil {
                        // use getItem instead of getItemCleanEnd because we don't want / need to split items.
                        // case 2
                        if conflictingItems[transaction.doc.store.getItem(item.origin)] == nil {
                            left = item
                            conflictingItems.removeAll()
                        }
                    } else {
                        break
                    }
                    item = item!.right
                }
                self.left = left
            }
            
            if self.left != nil {
                let right = self.left!.right
                self.right = right
                self.left!.right = self
            } else {
                var r: Item?
                if self.parentSub != nil {
                    r = (self.parent as AbstractType)._map[parentSub]
                    while r != nil && r!.left !== nil {
                        r = r!.left
                    }
                } else {
                    r = (self.parent as! AbstractType)._start
                    (self.parent as! AbstractType)._start = self
                }
                self.right = r
            }
            if self.right != nil {
                self.right!.left = self
            } else if self.parentSub != nil {
                // set as current parent value if right == nil and this is parentSub
                (self.parent as! AbstractType)._map[self.parentSub] = self
                if self.left != nil {
                    // this is the current attribute value of parent. delete right
                    self.left!.delete(transaction)
                }
            }
            // adjust length of parent
            if self.parentSub == nil && self.countable && !self.deleted {
                (self.parent as! AbstractType)._length += self.length
            }
            transaction.doc.store.addStruct(self)
            self.content.integrate(transaction, self)
            // add parent to transaction.changed
            transaction.addChangedType((self.parent as! AbstractType), self.parentSub)
            if ((self.parent as AbstractType)._item != nil && (self.parent as! AbstractType)._item!.deleted)
                || (self.parentSub != nil && self.right != nil)
            {
                // delete if parent is deleted or if this is not the current attribute value of parent
                self.delete(transaction)
            }
        } else {
            // parent is not defined. Integrate GC struct instead
            GC(self.id, self.length).integrate(transaction, 0)
        }
    }

    public var next: Item? {
        var n = self.right
        while (n != nil && n!.deleted) { n = n!.right }
        return n
    }

    public var prev: Item? {
        var n = self.left
        while(n != nil && n!.deleted) { n = n!.left }
        return n
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

    /** Try to merge two items */
    public func merge(with right: Item) -> Bool {
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
            self.content.constructor == right.content.constructor &&
            self.content.merge(with: right.content)
        ) {
            let searchMarker = (self.parent as AbstractType)._searchMarker
            if searchMarker != nil {
                searchMarker.forEach({ marker in
                    if marker.item == right {
                        marker.item = self
                        if !self.deleted && self.countable { marker.index -= self.length }
                    }
                })
            }
            
            if right.keep { self.keep = true }
            self.right = right.right
            if self.right != nil { self.right!.left = self }
            self.length += right.length
            return true
        }
        return false
    }

    /** Mark this Item as deleted. */
    public func delete(_ transaction: Transaction) {
        if !self.deleted {
            let parent = self.parent as! AbstractType
            // adjust the length of parent
            if self.countable && self.parentSub == nil {
                parent._length -= self.length
            }
            self.markDeleted()
            transaction.deleteSet.add(client: self.id.client, clock: self.id.clock, length: self.length)
            transaction.addChangedType(parent, self.parentSub)
            self.content.delete(transaction: transaction)
        }
    }

    public func gc(_ store: StructStore, parentGCd: Bool) throws {
        if !self.deleted {
            throw YSwiftError.unexpectedCase
        }
        self.content.gc(store)
        if parentGCd {
            store.replaceStruct(self, GC(self.id, self.length))
        } else {
            self.content = ContentDeleted(self.length)
        }
    }

    /**
     * Transform the properties of this type to binary and write it to an
     * BinaryEncoder.
     *
     * This is called when this Item is sent to a remote peer.
     */
    public func write(_ encoder: UpdateEncoder, offset: UInt) throws {
        let origin = offset > 0 ? ID(client: self.id.client, clock: self.id.clock + offset - 1) : self.origin
        let rightOrigin = self.rightOrigin
        let parentSub = self.parentSub
        let info: UInt8 = (self.content.getRef() & 0b0001_1111) |
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
            let parent = (self.parent as AbstractType)
            if parent._item != nil {
                let parentItem = parent._item
                if parentItem == nil {
                    // parent type on y._map
                    // find the correct key
                    let ykey = findRootTypeKey(parent)
                    encoder.writeParentInfo(true) // write parentYKey
                    encoder.writeString(ykey)
                } else {
                    encoder.writeParentInfo(false) // write parent id
                    encoder.writeLeftID(parentItem.id)
                }
            } else if parent.constructor == String { // this edge case was added by differential updates
                encoder.writeParentInfo(true) // write parentYKey
                encoder.writeString(parent)
            } else if parent.constructor == ID {
                encoder.writeParentInfo(false) // write parent id
                encoder.writeLeftID(parent)
            } else {
                throw YSwiftError.unexpectedCase
            }
            if parentSub != nil {
                encoder.writeString(parentSub!)
            }
        }
        
        self.content.write(encoder, offset)
    }
}

func readItemContent(decoder: UpdateDecoder, info: UInt8) -> any Content {
    return contentDecoders_[info & 0b0001_1111](decoder)
}

/** A lookup map for reading Item content. */
let contentDecoders_: [YContentDecoder] = [
    () -> { throw Lib0UnexpectedCaseError() }, // GC is not ItemContent
    readContentDeleted, // 1
    readContentJSON, // 2
    readContentBinary, // 3
    readContentString, // 4
    readContentEmbed, // 5
    readContentFormat, // 6
    readContentType, // 7
    readContentAny, // 8
    readContentDoc, // 9
    () -> { throw Lib0UnexpectedCaseError() } // 10 - Skip is not ItemContent
]

