//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

/** YEvent describes the changes on a YType. */
public class YEvent {
    public var target: YOpaqueObject // T
    public var currentTarget: YOpaqueObject
    public var transaction: YTransaction
    
    var _changes: YEventChange? = nil
    var _keys: [String: YEventKey]? = nil
    var _delta: [YEventDelta]? = nil

    init(_ target: YOpaqueObject, transaction: YTransaction) {
        self.target = target
        self.currentTarget = target
        self.transaction = transaction
    }

    public var path: [PathElement] {
        return YEvent.getPathTo(parent: self.currentTarget, child: self.target)
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
                while (prev != nil && self.adds(prev!)) { prev = (prev as! YItem).left }
                
                if self.deletes(item) {
                    if prev != nil && self.deletes(prev!) {
                        action = .delete
                        oldValue = (prev as! YItem).content.values.last ?? nil
                    } else { return }
                } else {
                    if prev != nil && self.deletes(prev!) {
                        action = .update
                        oldValue = (prev as! YItem).content.values.last ?? nil
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

    public func delta() -> [YEventDelta] {
        return self.changes().delta
    }

    func adds(_ struct_: YStruct) -> Bool {
        return struct_.id.clock >= (self.transaction.beforeState[struct_.id.client] ?? 0)
    }
    func deletes(_ struct_: YStruct) -> Bool {
        return self.transaction.deleteSet.isDeleted(struct_.id)
    }

    public func changes() -> YEventChange {
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
                
                item = item!.right as? YItem
            }
            if lastDelta != nil && lastDelta!.retain == nil {
                packDelta()
            }
        }
        self._changes = changes
        return changes
    }
}

extension YEvent {
    public enum PathElement: Equatable, Hashable {
        case index(Int)
        case key(String)
    }
    
    private static func getPathTo(parent: YOpaqueObject, child: YOpaqueObject) -> [PathElement] {
        var child: YOpaqueObject? = child
        var path: [PathElement] = []
        while let childItem = child?.item, child != parent {
            if let parentKey = childItem.parentKey {
                // parent is map-ish
                path.insert(.key(parentKey), at: 0)
            } else {
                // parent is array-ish
                var i = 0
                var item = childItem.parent?.object?._start
                while let uitem = item, item != childItem {
                    if !uitem.deleted { i += 1 }
                    item = uitem.right as? YItem
                }
                path.insert(.index(i), at: 0)
            }
            child = childItem.parent?.object
        }
        return path
    }
}

