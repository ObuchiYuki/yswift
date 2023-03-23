//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

public protocol YEventDeltaInsertType {}
extension NSNumber: YEventDeltaInsertType {}
extension NSDictionary: YEventDeltaInsertType {}
extension NSArray: YEventDeltaInsertType {}

extension String: YEventDeltaInsertType {}
extension [Any?]: YEventDeltaInsertType {}
extension [String: Any?]: YEventDeltaInsertType {}
extension AbstractType: YEventDeltaInsertType {}

extension YEventDeltaInsertType {
    public func isEqual(to other: any YEventDeltaInsertType) -> Bool {
        if equalJSON(self, other) { return true }
        if let a = self as? AbstractType, let b = other as? AbstractType {
            return equalJSON(a.toJSON(), b.toJSON())
        }
        return false
    }
}

public class YEventDelta {
    public var insert: YEventDeltaInsertType?
    public var retain: Int?
    public var delete: Int?
    public var attributes: YTextAttributes? 
    
    public init(insert: YEventDeltaInsertType? = nil, retain: Int? = nil, delete: Int? = nil, attributes: YTextAttributes? = nil) {
        self.insert = insert
        self.retain = retain
        self.delete = delete
        self.attributes = attributes
    }
    
    public init(insert: YEventDeltaInsertType? = nil, retain: Int? = nil, delete: Int? = nil, attributes: [String: YTextAttributeValue?]) {
        self.insert = insert
        self.retain = retain
        self.delete = delete
        self.attributes = Ref(value: attributes)
    }
}

extension YEventDelta: CustomStringConvertible {
    public var description: String {
        var dict = [String: Any]()
        dict["insert"] = insert
        dict["retain"] = retain
        dict["delete"] = delete
        dict["attributes"] = attributes
        return dict.description
    }
}

extension YEventDelta: Equatable {
    public static func == (lhs: YEventDelta, rhs: YEventDelta) -> Bool {
        return optionalEqual(lhs.insert, rhs.insert, compare: { $0.isEqual(to: $1) })
        && lhs.retain == rhs.retain
        && lhs.delete == rhs.delete
        && optionalEqual(lhs.attributes, rhs.attributes, compare: { $0.isEqual(to: $1) })
    }
}

public enum YEventAction: String {
    case add, update, delete
}

public class YEventKey {
    public var action: YEventAction
    public var oldValue: Any?
    public var newValue: Any?
    
    init(action: YEventAction, oldValue: Any? = nil, newValue: Any? = nil) {
        self.action = action
        self.oldValue = oldValue
        self.newValue = newValue
    }
}

public class YEventChange {
    public var added: Set<Item>
    public var deleted: Set<Item>
    public var keys: [String: YEventKey]
    public var delta: [YEventDelta]
    
    init(added: Set<Item>, deleted: Set<Item>, keys: [String : YEventKey], delta: [YEventDelta]) {
        self.added = added
        self.deleted = deleted
        self.keys = keys
        self.delta = delta
    }
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
                while (prev != nil && self.adds(prev!)) { prev = (prev as! Item).left }
                
                if self.deletes(item) {
                    if prev != nil && self.deletes(prev!) {
                        action = .delete
                        oldValue = (prev as! Item).content.getContent().last ?? nil
                    } else { return }
                } else {
                    if prev != nil && self.deletes(prev!) {
                        action = .update
                        oldValue = (prev as! Item).content.getContent().last ?? nil
                    } else {
                        action = .add
                        oldValue = nil
                    }
                }
            } else {
                if self.deletes(item) {
                    action = .delete
                    oldValue = item.content.getContent().last ?? nil
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
        
        let changes = YEventChange(added: Set(), deleted: Set(), keys: self.keys, delta: [])
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
                c = c!.right as? Item
            }
            path.insert(i, at: 0)
        }
        child = child._item!.parent as! AbstractType
    }
    return path
}
