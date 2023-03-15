//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

public protocol YEventDeltaInsertType {}
extension String: YEventDeltaInsertType {}
extension [Any]: YEventDeltaInsertType {}
extension [String: Any]: YEventDeltaInsertType {}
extension AbstractType: YEventDeltaInsertType {}

public struct YEventDelta {
    public var insert: YEventDeltaInsertType?
    public var retain: UInt?
    public var delete: UInt?
    public var attributes: [String: Any]?
}

public enum YEventAction: String {
    case add, update, delete
}

public struct YEventKey {
    public var action: YEventAction
    public var oldValue: Any
    public var newValue: Any?
}

public struct YEventChange {
    public var added: Set<Item>
    public var deleted: Set<Item>
    public var keys: [String: YEventKey]
    public var delta: [YEventDelta]
}

/** YEvent describes the changes on a YType. */
public class YEvent {
    public var target: AbstractType // T
    public var currentTarget: AbstractType
    public var transaction: Transaction
    
    public var _changes: YEventChange? = nil
    public var _keys: [String: YEventKey]? = nil
    public var _delta: [YEventDelta]? = nil

    public init(_ target: AbstractType, transaction: Transaction) {
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
            
            let item = target._map[key!]!
            var action: YEventAction!
            var oldValue: Any?

            if self.adds(item) {
                var prev = item.left
                while (prev != nil && self.adds(prev!)) { prev = prev!.left }
                
                if self.deletes(item) {
                    if prev != nil && self.deletes(prev!) {
                        action = .delete
                        oldValue = prev!.content.getContent().last
                    } else { return }
                } else {
                    if prev != nil && self.deletes(prev!) {
                        action = .update
                        oldValue = prev!.content.getContent().last
                    } else {
                        action = .add
                        oldValue = nil
                    }
                }
            } else {
                if self.deletes(item) {
                    action = .delete
                    oldValue = item.content.getContent().last
                } else { return }
            }

            let event = YEventKey(action: action, oldValue: oldValue)
            keys[key!] = event
        }

        self._keys = keys
        return keys
    }

    public var delta: [YEventDelta] {
        return self.changes.delta
    }

    /**
     * Check if a struct is added by this event.
     *
     * In contrast to change.deleted, this method also returns true if the struct was added and then deleted.
     */
    public func adds(_ struct_: Struct) -> Bool {
        return struct_.id.clock >= (self.transaction.beforeState[Int(struct_.id.client)] ?? 0)
    }

    public var changes: YEventChange {
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
                        lastDelta!.insert = lastDelta!.insert as! [Any] + item!.content.getContent()
                        changes.added.insert(item!)
                    } else {
                        if lastDelta == nil || lastDelta!.retain == nil {
                            packDelta()
                            lastDelta = YEventDelta(retain: 0)
                        }
                        lastDelta!.retain! += item!.length
                    }
                }
                
                item = item!.right
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

func getPathTo(parent: AbstractType, child: AbstractType) -> [PathElement] {
    var child = child
    var path: [PathElement] = []
    while (child._item != nil && child != parent) {
        if child._item!.parentSub != nil {
            // parent is map-ish
            path.insert(child._item!.parentSub!, at: 0)
        } else {
            // parent is array-ish
            var i = 0
            var c = (child._item!.parent as! AbstractType)._start
            while (c != child._item && c != nil) {
                if !c!.deleted {
                    i += 1
                }
                c = c!.right
            }
            path.insert(i, at: 0)
        }
        child = child._item!.parent as! AbstractType
    }
    return path
}
