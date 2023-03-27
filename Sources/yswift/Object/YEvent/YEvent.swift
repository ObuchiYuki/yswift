//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

/** YEvent describes the changes on a YType. */
public class YEvent {
    public var target: YObject // T
    public var currentTarget: YObject
    public var transaction: Transaction
    
    var _changes: YEventChange? = nil
    var _keys: [String: YEventKey]? = nil
    var _delta: [YEventDelta]? = nil

    init(_ target: YObject, transaction: Transaction) {
        self.target = target
        self.currentTarget = target
        self.transaction = transaction
    }

    public var path: [PathElement] {
        return getPathTo(parent: self.currentTarget, child: self.target)
    }

    public func deletes(_ struct_: Struct) -> Bool {
        return self.transaction.deleteSet.isDeleted(struct_.id)
    }

    public var keys: [String: YEventKey] {
        if (self._keys != nil) { return self._keys! }

        var keys = [String: YEventKey]()
        let target = self.target
        let changed = self.transaction.changed[target]!

        changed.forEach{ key in
            if key == nil { return }
            
            let item = target.storage[key!]!
            var action: YEventAction!
            var oldValue: Any?

            if self.adds(item) {
                var prev = item.left
                while (prev != nil && self.adds(prev!)) { prev = (prev as! Item).left }
                
                if self.deletes(item) {
                    if prev != nil && self.deletes(prev!) {
                        action = .delete
                        oldValue = (prev as! Item).content.values.last ?? nil
                    } else { return }
                } else {
                    if prev != nil && self.deletes(prev!) {
                        action = .update
                        oldValue = (prev as! Item).content.values.last ?? nil
                    } else {
                        action = .add
                        oldValue = nil
                    }
                }
            } else {
                if self.deletes(item) {
                    action = .delete
                    oldValue = item.content.values.last ?? nil
                } else { return }
            }

            let event = YEventKey(action: action, oldValue: oldValue)
            keys[key!] = event
        }

        self._keys = keys
        return keys
    }

    public func delta() throws -> [YEventDelta] {
        return try self.changes().delta
    }

    /**
     * Check if a struct is added by this event.
     *
     * In contrast to change.deleted, this method also returns true if the struct was added and then deleted.
     */
    public func adds(_ struct_: Struct) -> Bool {
        return struct_.id.clock >= (self.transaction.beforeState[struct_.id.client] ?? 0)
    }

    public func changes() throws -> YEventChange {
        if (self._changes != nil) { return self._changes! }
        
        var changes = YEventChange(added: Set(), deleted: Set(), keys: self.keys, delta: [])
        let changed = self.transaction.changed[self.target]!
        
        if changed.contains(nil) {
            var lastDelta: YEventDelta? = nil
            func packDelta() {
                if lastDelta != nil { changes.delta.append(lastDelta!) }
            }
            
            var item = self.target._start
            
            while item != nil {
                if item!.deleted {
                    if self.deletes(item!) && !self.adds(item!) {
                        if lastDelta == nil || lastDelta!.delete == nil {
                            packDelta()
                            lastDelta = YEventDelta(delete: 0)
                        }
                        lastDelta!.delete! += item!.length
                        changes.deleted.insert(item!)
                    } // else nop
                } else {
                    if self.adds(item!) {
                        if lastDelta == nil || lastDelta!.insert == nil {
                            packDelta()
                            lastDelta = YEventDelta(insert: [])
                        }
                        lastDelta!.insert = lastDelta!.insert as! [Any] + item!.content.values
                        changes.added.insert(item!)
                    } else {
                        if lastDelta == nil || lastDelta!.retain == nil {
                            packDelta()
                            lastDelta = YEventDelta(retain: 0)
                        }
                        lastDelta!.retain! += item!.length
                    }
                }
                
                item = item!.right as? Item
            }
            if lastDelta != nil && lastDelta!.retain == nil {
                packDelta()
            }
        }
        self._changes = changes
        return changes
    }
}

public protocol PathElement {}
extension String: PathElement {}
extension Int: PathElement {}

func getPathTo(parent: YObject, child: YObject) -> [PathElement] {
    var child: YObject? = child
    var path: [PathElement] = []
    while let childItem = child?.item, child != parent {
        if let parentKey = childItem.parentKey {
            // parent is map-ish
            path.insert(parentKey, at: 0)
        } else {
            // parent is array-ish
            var i = 0
            var item = childItem.parent?.object?._start
            while let uitem = item, item != childItem {
                if !uitem.deleted { i += 1 }
                item = uitem.right as? Item
            }
            path.insert(i, at: 0)
        }
        child = childItem.parent?.object
    }
    return path
}
