//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

public enum YChangeAction: String {
    case removed = "removed"
    case added = "added"
}

public protocol YTextAttributeValue {}
extension Bool: YTextAttributeValue {}
extension NSNumber: YTextAttributeValue {}
extension String: YTextAttributeValue {}
extension [Any?]: YTextAttributeValue {}
extension [String: Any?]: YTextAttributeValue {}
extension NSNull: YTextAttributeValue {}

extension YTextAttributeValue {
    func jsProperty(_ name: String) -> Any? {
        removeDualOptional((self as? [String: Any?])?[name])
    }
    func jsPropertyTyped<T>(_: T.Type, name: String) -> T? {
        removeDualOptional((self as? [String: Any?])?[name] as? T)
    }
}

public typealias YTextAttributes = Ref<[String: YTextAttributeValue?]>

extension YTextAttributes {
    public func isEqual(to other: YTextAttributes) -> Bool {
        self.value.allSatisfy{ key, value in
            equalJSON(value, other.value[key] ?? nil)
        }
    }
}


public enum YTextAction: String {
    case delete = "delete"
    case insert = "insert"
    case retain = "retain"
}

public class ItemTextListPosition {
    public var left: Item?
    public var right: Item?
    public var index: Int
    public var currentAttributes: YTextAttributes
    
    public init(left: Item?, right: Item?, index: Int, currentAttributes: YTextAttributes) {
        self.left = left
        self.right = right
        self.index = index
        self.currentAttributes = currentAttributes
    }

    public func forward() throws {
        if self.right == nil { throw YSwiftError.unexpectedCase }
        
        if self.right!.content is ContentFormat {
            if !self.right!.deleted {
                updateCurrentAttributes(currentAttributes: self.currentAttributes, format: self.right!.content as! ContentFormat)
            }
        } else {
            if !self.right!.deleted {
                self.index += Int(self.right!.length)
            }
        }
        self.left = self.right
        self.right = self.right!.right as? Item
    }

    public func findNext(_ transaction: Transaction, count: Int) throws -> ItemTextListPosition {
        var count = count
        
        while (self.right != nil && count > 0) {
            if self.right!.content is ContentFormat {
                if !self.right!.deleted {
                    updateCurrentAttributes(currentAttributes: self.currentAttributes, format: self.right!.content as! ContentFormat)
                }
            } else {
                if !self.right!.deleted {
                    if count < self.right!.length {
                        // split right
                        try StructStore.getItemCleanStart(transaction, id: ID(client: self.right!.id.client, clock: self.right!.id.clock + count))
                    }
                    self.index += Int(self.right!.length)
                    count -= Int(self.right!.length)
                }
            }
            self.left = self.right!
            self.right = self.right!.right as? Item
        }
        return self
    }

    static public func find(_ transaction: Transaction, parent: AbstractType, index: Int) throws -> ItemTextListPosition {
        let currentAttributes: YTextAttributes = .init(value: [:])
        
        let marker = ArraySearchMarker.find(parent, index: index)
        if marker != nil && marker!.item != nil {
            let pos = ItemTextListPosition(
                left: marker!.item!.left as? Item,
                right: marker!.item!,
                index: marker!.index,
                currentAttributes: currentAttributes
            )
            return try pos.findNext(transaction, count: index - marker!.index)
        } else {
            let pos = ItemTextListPosition(left: nil, right: parent._start, index: 0, currentAttributes: currentAttributes)
            return try pos.findNext(transaction, count: index)
        }
    }

}

public func insertNegatedAttributes(
    transaction: Transaction,
    parent: AbstractType,
    currPos: ItemTextListPosition,
    negatedAttributes: YTextAttributes
) throws {
    // check if we really need to remove attributes
    while (
        currPos.right != nil && (
            currPos.right!.deleted == true || (
                currPos.right!.content is ContentFormat &&
                equalAttributes(
                    removeDualOptional(
                        negatedAttributes.value[(currPos.right!.content as! ContentFormat).key]
                    ),
                    (currPos.right!.content as! ContentFormat).value
                )
            )
        )
    ) {
        if !currPos.right!.deleted {
            negatedAttributes.value.removeValue(forKey: (currPos.right!.content as! ContentFormat).key)
        }
        try currPos.forward()
    }
    let doc = transaction.doc
    let ownClientId = doc.clientID
        
    try negatedAttributes.forEach({ key, val in
        let left = currPos.left
        let right = currPos.right
        let nextFormat = Item(
            id: ID(client: ownClientId, clock: doc.store.getState(ownClientId)),
            left: left,
            origin: left?.lastID,
            right: right,
            rightOrigin: right?.id,
            parent: parent,
            parentSub: nil,
            content: ContentFormat(key: key, value: val)
        )
        try nextFormat.integrate(transaction: transaction, offset: 0)
        currPos.right = nextFormat
        try currPos.forward()
    })
}

public func updateCurrentAttributes(currentAttributes: YTextAttributes, format: ContentFormat) {
    let key = format.key, value = format.value
    if value == nil {
        currentAttributes.value.removeValue(forKey: key)
    } else {
        currentAttributes.value[key] = value
    }
}

func minimizeAttributeChanges(currPos: ItemTextListPosition, attributes: YTextAttributes) throws {
    // go right while attributes[right.key] == right.value (or right is deleted)
    while (true) {
        if currPos.right == nil {
            break
        } else if currPos.right!.deleted
                    || (currPos.right!.content is ContentFormat
                        && equalAttributes(
                            removeDualOptional(attributes.value[(currPos.right!.content as! ContentFormat).key]),
                            (currPos.right!.content as! ContentFormat).value
                        )
                    )
        {
            //
        } else {
            break
        }
        try currPos.forward()
    }
}

public func insertAttributes(
    transaction: Transaction,
    parent: AbstractType,
    currPos: ItemTextListPosition,
    attributes: YTextAttributes
) throws -> YTextAttributes {
    let doc = transaction.doc
    let ownClientId = doc.clientID
    let negatedAttributes: YTextAttributes = .init(value: [:])
    // insert format-start items

    for (key, val) in attributes {
        let currentVal = currPos.currentAttributes.value[key]
        
        print("== insert ==", removeDualOptional(currentVal), val)
        
        if !equalAttributes(removeDualOptional(currentVal), val) {
            // save negated attribute (set nil if currentVal undefined)
            negatedAttributes.value[key] = currentVal == nil ? NSNull() : currentVal
            
            let left = currPos.left, right = currPos.right
            currPos.right = Item(
                id: ID(client: ownClientId, clock: doc.store.getState(ownClientId)),
                left: left,
                origin: left?.lastID,
                right: right,
                rightOrigin: right?.id,
                parent: parent, parentSub: nil,
                content: ContentFormat(key: key, value: val)
            )
            try currPos.right!.integrate(transaction: transaction, offset: 0)
            try currPos.forward()
        }
    }
    
    print("negatedAttributes", negatedAttributes)
    
    return negatedAttributes
}


public func insertText(
    transaction: Transaction,
    parent: AbstractType,
    currPos: ItemTextListPosition,
    text: YEventDeltaInsertType,
    attributes: YTextAttributes
) throws {
    // TODO: remove
    currPos.currentAttributes.forEach({ key, _ in
        // TODO: ??? what is this ???
        if attributes.value[key] == nil {
            attributes.value[key] = nil
        }
    })
    
    let doc = transaction.doc
    let ownClientId = doc.clientID
    try minimizeAttributeChanges(currPos: currPos, attributes: attributes)
    let negatedAttributes = try insertAttributes(transaction: transaction, parent: parent, currPos: currPos, attributes: attributes)
    // insert content
    let content = text is String
        ? ContentString((text as! String as NSString)) as any Content
        : (text is AbstractType
           ? ContentType(text as! AbstractType) as any Content
           : ContentEmbed(text as! [String: Any?]) as any Content
        )
    
    var left = currPos.left, right = currPos.right, index = currPos.index
    
    if parent._searchMarker != nil {
        ArraySearchMarker.updateChanges(parent._searchMarker!, index: currPos.index, len: content.getLength())
    }
    right = Item(
        id: ID(client: ownClientId, clock: doc.store.getState(ownClientId)),
        left: left,
        origin: left?.lastID,
        right: right,
        rightOrigin: right?.id,
        parent: parent,
        parentSub: nil,
        content: content
    )
    try right!.integrate(transaction: transaction, offset: 0)
    currPos.right = right
    currPos.index = index
    try currPos.forward()
        
    try insertNegatedAttributes(transaction: transaction, parent: parent, currPos: currPos, negatedAttributes: negatedAttributes)
}
 
public func formatText(
    transaction: Transaction,
    parent: AbstractType,
    currPos: ItemTextListPosition,
    length: Int,
    attributes: YTextAttributes
) throws {
    var length = length
    let doc = transaction.doc
    let ownClientId = doc.clientID
    try minimizeAttributeChanges(currPos: currPos, attributes: attributes)
    let negatedAttributes = try insertAttributes(transaction: transaction, parent: parent, currPos: currPos, attributes: attributes)
    // iterate until first non-format or nil is found
    // delete all formats with attributes[format.key] != nil
    // also check the attributes after the first non-format as we do not want to insert redundant negated attributes there
    // eslint-disable-next-line no-labels
    iterationLoop: while (
        currPos.right != nil &&
        (length > 0 ||
            (
                negatedAttributes.count > 0 &&
                (currPos.right!.deleted || currPos.right!.content is ContentFormat)
            )
        )
    ) {
        if !currPos.right!.deleted {
            switch true {
            case currPos.right!.content is ContentFormat:
                let __contentFormat = currPos.right!.content as! ContentFormat
                let key = __contentFormat.key, value = __contentFormat.value
                let attr = attributes.value[key]
                if attr != nil {
                    if equalAttributes(removeDualOptional(attr), value) {
                        negatedAttributes.value.removeValue(forKey: key)
                    } else {
                        if length == 0 {
                            break iterationLoop
                        }
                        negatedAttributes.value[key] = value
                    }
                    currPos.right!.delete(transaction)
                } else {
                    currPos.currentAttributes.value[key] = value
                }
                
            default:
                if length < currPos.right!.length {
                    try StructStore.getItemCleanStart(
                        transaction,
                        id: ID(client: currPos.right!.id.client, clock: currPos.right!.id.clock + length)
                    )
                }
                length -= currPos.right!.length
            }
        }
        try currPos.forward()
    }
    
    if length > 0 {
        var newlines = ""
        while length > 0 {
            newlines += "\n"
        }
        
        currPos.right = Item(
            id: ID(client: ownClientId, clock: doc.store.getState(ownClientId)),
            left: currPos.left,
            origin: currPos.left?.lastID,
            right: currPos.right,
            rightOrigin: currPos.right?.id,
            parent: parent,
            parentSub: nil,
            content: ContentString(newlines as NSString)
        )
        try currPos.right!.integrate(transaction: transaction, offset: 0)
        try currPos.forward()
        
        length -= 1
    }
    try insertNegatedAttributes(transaction: transaction, parent: parent, currPos: currPos, negatedAttributes: negatedAttributes)
}

public func cleanupFormattingGap(
    transaction: Transaction,
    start: Item,
    curr: Item?,
    startAttributes: YTextAttributes,
    currAttributes: YTextAttributes
) -> Int {
    var start: Item? = start // swift add
    var end: Item? = start
    var endFormats = [String: ContentFormat]()
    while (end != nil && (!end!.countable || end!.deleted)) {
        if !end!.deleted && end!.content is ContentFormat {
            let cf = end!.content as! ContentFormat
            endFormats[cf.key] = cf
        }
        end = end!.right as? Item
    }
    var cleanups = 0
    var reachedCurr = false
    while (start != nil && start != end) {
        if curr == start {
            reachedCurr = true
        }
        if !start!.deleted {
            let content = start!.content
            switch true {
            case content is ContentFormat:
                let __contentFormat = content as! ContentFormat
                let key = __contentFormat.key, value = __contentFormat.value
                let startAttrValue = startAttributes.value[key]
                // OLD: ... || startAttrValue == value
                if endFormats[key] !== content as (any Content)? || jsStrictEqual(removeDualOptional(startAttrValue), value) {
                    // Either this format is overwritten or it is not necessary because the attribute already existed.
                    start!.delete(transaction)
                    cleanups += 1
                    if !reachedCurr && jsStrictEqual(removeDualOptional(currAttributes.value[key]), value) && !jsStrictEqual(removeDualOptional(startAttrValue), value) {
                        if startAttrValue == nil {
                            currAttributes.value.removeValue(forKey: key)
                        } else {
                            currAttributes.value[key] = startAttrValue
                        }
                    }
                }
                if !reachedCurr && !start!.deleted {
                    updateCurrentAttributes(currentAttributes: currAttributes, format: content as! ContentFormat)
                }
                break
            default: break // nop
            }
        }
        start = start!.right! as? Item
    }
    return cleanups
}

func cleanupContextlessFormattingGap(transaction: Transaction, item: Item?) {
    var item = item // swift add
    // iterate until item.right is nil or content
    while (item != nil && item!.right != nil && (item!.right!.deleted || !(item!.right as! Item).countable)) {
        item = item!.right as? Item
    }
    var attrs = Set<String>()
    // iterate back until a content item is found
    while (item != nil && (item!.deleted || !item!.countable)) {
        if !item!.deleted && item!.content is ContentFormat {
            let key = (item!.content as! ContentFormat).key
            if attrs.contains(key) {
                item!.delete(transaction)
            } else {
                attrs.insert(key)
            }
        }
        item = item!.left as? Item
    }
}

func cleanupYTextFormatting(type: YText) throws -> Int {
    var res = 0
    try type.doc?.transact({ transaction in
        var start = type._start!
        var end = type._start
        var startAttributes = YTextAttributes(value: [:])
        let currentAttributes = YTextAttributes(value: [:])
        while end != nil {
            if end!.deleted == false {
                if end!.content is ContentFormat {
                    updateCurrentAttributes(currentAttributes: currentAttributes, format: end!.content as! ContentFormat)
                } else {
                    res += cleanupFormattingGap(
                        transaction: transaction, start: start, curr: end!, startAttributes: startAttributes, currAttributes: currentAttributes
                    )
                    startAttributes = currentAttributes
                    start = end!
                }
            }
            end = end!.right as? Item
        }
    })
    return res
}

public func deleteText(
    transaction: Transaction,
    currPos: ItemTextListPosition,
    length: Int
) throws -> ItemTextListPosition {
    var length = length
    let startLength = length
    let startAttrs = currPos.currentAttributes
    let start = currPos.right
    while (length > 0 && currPos.right != nil) {
        if currPos.right!.deleted == false {
            if currPos.right!.content is ContentType ||
                currPos.right!.content is ContentEmbed ||
                currPos.right!.content is ContentString {
                if length < currPos.right!.length {
                    try StructStore.getItemCleanStart(
                        transaction,
                        id: ID(client: currPos.right!.id.client, clock: currPos.right!.id.clock + length)
                    )
                }
                length -= Int(currPos.right!.length)
                currPos.right!.delete(transaction)
            }
        }
        try currPos.forward()
    }
    if start != nil {
        _ = cleanupFormattingGap(
            transaction: transaction,
            start: start!,
            curr: currPos.right,
            startAttributes: startAttrs,
            currAttributes: currPos.currentAttributes
        )
    }
    
    let parent = ((currPos.left ?? currPos.right!).parent as! AbstractType)
    if parent._searchMarker != nil {
        ArraySearchMarker.updateChanges(parent._searchMarker!, index: currPos.index, len: -startLength + length)
    }
    return currPos
}


public class YTextEvent: YEvent {

    public var childListChanged: Bool

    public var keysChanged: Set<String>

    public init(_ ytext: YText, transaction: Transaction, subs: Set<String?>) {
        self.childListChanged = false
        self.keysChanged = Set()
        
        super.init(ytext, transaction: transaction)

        subs.forEach({ sub in
            if sub == nil {
                self.childListChanged = true
            } else {
                self.keysChanged.insert(sub!)
            }
        })
    }
    
    public override func changes() throws -> YEventChange {
        if self._changes == nil {
            let changes = YEventChange(added: Set(), deleted: Set(), keys: self.keys, delta: try self.delta())
            self._changes = changes
        }
        return self._changes!
    }

    public override func delta() throws -> [YEventDelta] {
        if (self._delta != nil) { return self._delta! }

        var deltas: [YEventDelta] = []

        try self.target.doc?.transact({ transaction in
            let currentAttributes = YTextAttributes(value: [:]) // saves all current attributes for insert
            let oldAttributes = YTextAttributes(value: [:])
            var item = self.target._start
            var action: YTextAction? = nil
            
            let attributes: YTextAttributes = .init(value: [:]) // counts added or removed attributes for retain
            
            var insert: String = ""
            var retain = 0
            var deleteLen = 0

            func addDelta() {
                if (action == nil) { return }

                var delta: YEventDelta

                if action == .delete {
                    delta = YEventDelta(delete: deleteLen)
                    deleteLen = 0
                } else if action == .insert {
                    delta = YEventDelta(insert: insert)
                    if currentAttributes.count > 0 {
                        delta.attributes = .init(value: [:])
                        currentAttributes.forEach({ key, value in
                            if value != nil { delta.attributes!.value[key] = value }
                        })
                    }
                    insert = ""
                } else {
                    delta = YEventDelta(retain: retain)
                    if attributes.value.keys.count > 0 {
                        delta.attributes = .init(value: [:])
                        for key in attributes.value.keys {
                            delta.attributes!.value[key] = removeDualOptional(attributes.value[key])
                        }
                    }
                    retain = 0
                }
                deltas.append(delta)
                action = nil
            }

            while (item != nil) {
                if item!.content is ContentType || item!.content is ContentEmbed {
                    if self.adds(item!) {
                        if !self.deletes(item!) {
                            addDelta()
                            action = .insert
                            insert = item!.content.getContent()[0] as! String
                            addDelta()
                        }
                    } else if self.deletes(item!) {
                        if action != .delete { addDelta(); action = .delete }
                        deleteLen += 1
                    } else if !item!.deleted {
                        if action != .retain { addDelta(); action = .retain }
                        retain += 1
                    }
                } else if item!.content is ContentString {
                    if self.adds(item!) {
                        if !self.deletes(item!) {
                            if action != .insert { addDelta(); action = .insert }
                            insert += (item!.content as! ContentString).str as String
                        }
                    } else if self.deletes(item!) {
                        if action != .delete { addDelta(); action = .delete }
                        deleteLen += Int(item!.length)
                    } else if !item!.deleted {
                        if action != .retain { addDelta(); action = .retain }
                        retain += Int(item!.length)
                    }
                } else if item!.content is ContentFormat {
                    let __contentFormat = item!.content as! ContentFormat
                    let key = __contentFormat.key, value = __contentFormat.value
                    
                    if self.adds(item!) {
                        if !self.deletes(item!) {
                            let curVal = currentAttributes.value[key]
                            if !equalAttributes(removeDualOptional(curVal), value) {
                                if action == .retain { addDelta() }
                                
                                if equalAttributes(value, removeDualOptional(oldAttributes.value[key])) {
                                    attributes.value.removeValue(forKey: key)
                                } else {
                                    attributes.value[key] = value
                                }
                            } else if value != nil {
                                item!.delete(transaction)
                            }
                        }
                    } else if self.deletes(item!) {
                        oldAttributes.value[key] = value
                        let curVal = currentAttributes.value[key]
                        if !equalAttributes(removeDualOptional(curVal), value) {
                            if action == .retain { addDelta() }
                            attributes.value[key] = curVal
                        }
                    } else if !item!.deleted {
                        oldAttributes.value[key] = value
                        let attr = attributes.value[key]
                        if attr != nil {
                            if !equalAttributes(removeDualOptional(attr), value) {
                                if action == .retain { addDelta() }
                                if value == nil {
                                    attributes.value.removeValue(forKey: key)
                                } else {
                                    attributes.value[key] = value
                                }
                            } else if attr != nil {
                                item!.delete(transaction)
                            }
                        }
                    }
                    if !item!.deleted {
                        if action == .insert { addDelta() }
                        updateCurrentAttributes(
                            currentAttributes: currentAttributes, format: (item!.content as! ContentFormat)
                        )
                    }
                }
                item = item!.right as? Item
            }
            
            addDelta()
            
            while (deltas.count > 0) {
                let lastOp = deltas[deltas.count - 1]
                if lastOp.retain != nil && lastOp.attributes == nil {
                    _ = deltas.popLast()
                } else {
                    break
                }
            }
        })

        self._delta = deltas
        return deltas
    }
}


public class YText: AbstractType {
    public var _pending: [(() throws -> Void)]?

    public init(_ string: String? = nil) {
        super.init()
        
        self._pending = string != nil ? [{
            // swift add
            try self.insert(0, text: string!, attributes: nil)
        }] : []
        self._searchMarker = .init(value: [])
    }

    public var length: Int { return self._length }

    public override func _integrate(_ y: Doc, item: Item?) throws {
        try super._integrate(y, item: item)

        do {
            try (self._pending)?.forEach{ try $0() }
        } catch {
            print(error)
        }
        self._pending = nil
    }

    public override func _copy() -> AbstractType {
        return YText()
    }

    public override func clone() throws -> AbstractType {
        let text = YText()
        try text.applyDelta(self.toDelta())
        return text
    }

    public override func _callObserver(_ transaction: Transaction, _parentSubs: Set<String?>) throws {
        try super._callObserver(transaction, _parentSubs: _parentSubs)
        let event = YTextEvent(self, transaction: transaction, subs: _parentSubs)
        let doc = transaction.doc
        
        try self.callObservers(transaction: transaction, event: event)
        
        if !transaction.local {
            // check if another formatting item was inserted
            var foundFormattingItem = false
            
            for (client, afterClock) in transaction.afterState {
                let clock = transaction.beforeState[client] ?? 0
                if afterClock == clock {
                    continue
                }
                
                try StructStore.iterateStructs(
                    transaction: transaction,
                    structs: doc.store.clients[client]!,
                    clockStart: clock,
                    len: afterClock,
                    f: { item in
                        if !item.deleted && (item as! Item).content is ContentFormat {
                            foundFormattingItem = true
                        }
                    }
                )
                
                if foundFormattingItem {
                    break
                }
            }
            
            if !foundFormattingItem {
                try transaction.deleteSet.iterate(transaction, body: { item in
                    if item is GC || foundFormattingItem {
                        return
                    }
                    if ((item as! Item).parent as? YText) === self && (item as! Item).content is ContentFormat {
                        foundFormattingItem = true
                    }
                })
            }

            try doc.transact({ t in
                if foundFormattingItem {
                    // If a formatting item was inserted, we simply clean the whole type.
                    // We need to compute currentAttributes for the current position anyway.
                    _ = try cleanupYTextFormatting(type: self)
                } else {
                    // If no formatting attribute was inserted, we can make due with contextless
                    // formatting cleanups.
                    // Contextless: it is not necessary to compute currentAttributes for the affected position.
                    try t.deleteSet.iterate(t, body: { item in
                        if item is GC {
                            return
                        }
                        if ((item as! Item).parent as? AbstractType) === self {
                            cleanupContextlessFormattingGap(transaction: t, item: (item as! Item))
                        }
                    })
                }
            })
        }
    }

    public func toString() -> String {
        var str = ""
        var n: Item? = self._start
        while (n != nil) {
            if !n!.deleted && n!.countable && n!.content is ContentString {
                str += (n!.content as! ContentString).str as String
            }
            n = n!.right as? Item
        }
        return str
    }

    public override func toJSON() -> Any {
        return self.toString()
    }
    
    public func applyDelta(_ delta: [YEventDelta], sanitize: Bool = true) throws {
        if self.doc != nil {
            try self.doc!.transact({ transaction in
                let currPos = ItemTextListPosition(left: nil, right: self._start, index: 0, currentAttributes: .init(value: [:]))
                for i in 0..<delta.count {
                    let op = delta[i]
                    if op.insert != nil {
                        let ins =
                            (!sanitize && op.insert! is String && i == delta.count - 1 && currPos.right == nil && (op.insert as! String).last == "\n")
                                ? String((op.insert as! String)[..<(op.insert as! String).endIndex]) as YEventDeltaInsertType
                                : op.insert!
                        
                        if !(ins is String) || (ins as! String).count > 0 {
                            try insertText(transaction: transaction, parent: self, currPos: currPos, text: ins, attributes: op.attributes ?? .init(value: [:]))
                        }
                    } else if op.retain != nil {
                        // swift add
                        try formatText(
                            transaction: transaction,
                            parent: self,
                            currPos: currPos,
                            length: op.retain!,
                            attributes: op.attributes ?? .init(value: [:])
                        )
                    } else if op.delete != nil {
                        _ = try deleteText(transaction: transaction, currPos: currPos, length: Int(op.delete!))
                    }
                }
            })
        } else {
            self._pending?.append{
                try self.applyDelta(delta)
            }
        }
    }

    /** Returns the Delta representation of this YText type. */
    public func toDelta(
        _ snapshot: Snapshot? = nil,
        prevSnapshot: Snapshot? = nil,
        computeYChange: ((YChangeAction, ID) -> YTextAttributeValue)? = nil
    ) throws -> [YEventDelta] {
        var ops: [YEventDelta] = []
        let currentAttributes: YTextAttributes = .init(value: [:])
        let doc = self.doc!
        var str = ""
        var n = self._start
        
        func packStr() {
            if str.count > 0 {
                // pack str with attributes to ops
                let attributes: YTextAttributes = .init(value: [:])
                var addAttributes = false
                currentAttributes.forEach({ key, value in
                    addAttributes = true
                    attributes.value[key] = value
                })
                let op = YEventDelta(insert: str)
                if addAttributes {
                    op.attributes = attributes
                }
                ops.append(op)
                str = ""
            }
        }
        
        // snapshots are merged again after the transaction, so we need to keep the
        // transalive until we are done
        try doc.transact({ transaction in
            if snapshot != nil {
                try snapshot!.splitAffectedStructs(transaction)
            }
            if prevSnapshot != nil {
                try prevSnapshot!.splitAffectedStructs(transaction)
            }
            while n != nil {
                if n!.isVisible(snapshot) || (prevSnapshot != nil && n!.isVisible(prevSnapshot)) {
                    switch true {
                    case n!.content is ContentString:
                        let cur = removeDualOptional(currentAttributes.value["ychange"])
                        
                        if snapshot != nil && !n!.isVisible(snapshot) {
                            if cur == nil
                                || cur!.jsPropertyTyped(Int.self, name: "user") != n!.id.client
                                || cur!.jsPropertyTyped(String.self, name: "type") != "removed"
                            {
                                packStr()
                                currentAttributes.value["ychange"] = computeYChange != nil
                                    ? computeYChange!(.removed, n!.id)
                                    : ["type": "removed"]
                                
                            }
                        } else if prevSnapshot != nil && !n!.isVisible(prevSnapshot) {
                            if cur == nil
                                || cur!.jsPropertyTyped(Int.self, name: "user") != n!.id.client
                                || cur!.jsPropertyTyped(String.self, name: "type") != "added"
                            {
                                packStr()
                                currentAttributes.value["ychange"] = computeYChange != nil
                                    ? computeYChange!(.added, n!.id)
                                    : ["type": "added"]
                            }
                        } else if cur != nil {
                            packStr()
                            currentAttributes.value.removeValue(forKey: "ychange")
                        }
                        str += (n!.content as! ContentString).str as String
                    case n!.content is ContentType || n!.content is ContentEmbed:
                        packStr()
                        let op: YEventDelta = .init(insert: (n!.content.getContent()[0] as! YEventDeltaInsertType))
                        if currentAttributes.count > 0 {
                            op.attributes = .init(value: [:])
                            currentAttributes.forEach({ key, value in
                                op.attributes!.value[key] = value
                            })
                        }
                        ops.append(op)
                    case n!.content is ContentFormat:
                        if n!.isVisible(snapshot) {
                            packStr()
                            updateCurrentAttributes(currentAttributes: currentAttributes, format: n!.content as! ContentFormat)
                        }
                    default: break // nop
                    }
                }
                n = n!.right as? Item
            }
            packStr()
        }, origin: "cleanup")
        return ops
    }


    public func insert(_ index: Int, text: String, attributes: YTextAttributes? = nil) throws {
        if text.count <= 0 { return }
        
        guard let doc = self.doc else {
            self._pending?.append{ try self.insert(index, text: text, attributes: attributes) }
            return
        }
        
        try doc.transact({ transaction in
            let pos = try ItemTextListPosition.find(transaction, parent: self, index: index)
                        
            var attributes = attributes
            if attributes == nil {
                attributes = .init(value: [:])
                pos.currentAttributes.forEach{ k, v in
                    attributes!.value[k] = v
                }
            }

            try insertText(transaction: transaction, parent: self, currPos: pos, text: text, attributes: attributes!)
        })
    }

    // OLD: insertEmbed(_ index: Int, embed: AbstractType|object, attributes: YTextAttributes = {})
    public func insertEmbed(_ index: Int, embed: YEventDeltaInsertType, attributes: YTextAttributes?) throws {
        if self.doc != nil {
            try self.doc!.transact({ transaction in
                let pos = try ItemTextListPosition.find(transaction, parent: self, index: index)
                try insertText(transaction: transaction, parent: self, currPos: pos, text: embed, attributes: attributes!)
            })
        } else {
            (self._pending)?.append{
                try self.insertEmbed(index, embed: embed, attributes: attributes)
            }
        }
    }

    public func delete(_ index: Int, length: Int) throws {
        if length == 0 {
            return
        }
        if self.doc != nil {
            try self.doc!.transact({ transaction in
                _ = try deleteText(
                    transaction: transaction,
                    currPos: ItemTextListPosition.find(transaction, parent: self, index: index),
                    length: length
                )
            })
        } else {
            (self._pending)?.append {
                try self.delete(index, length: length)
            }
        }
    }

    public func format(_ index: Int, length: Int, attributes: YTextAttributes) throws {
        if length == 0 {
            return
        }
        if self.doc != nil {
            try self.doc!.transact({ transaction in
                let pos = try ItemTextListPosition.find(transaction, parent: self, index: index)
                if pos.right == nil {
                    return
                }
                try formatText(transaction: transaction, parent: self, currPos: pos, length: length, attributes: attributes)
            })
        } else {
            self._pending?.append{
                try self.format(index, length: length, attributes: attributes)
            }
        }
    }

    public func removeAttribute(_ attributeName: String) throws {
        if self.doc != nil {
            try self.doc!.transact({ transaction in
                self.mapDelete(transaction, key: attributeName)
            })
        } else {
            self._pending?.append {
                try self.removeAttribute(attributeName)
            }
        }
    }

    public func setAttribute(_ attributeName: String, attributeValue: YTextAttributeValue) throws {
        if self.doc != nil {
            try self.doc!.transact({ transaction in
                try self.mapSet(transaction, key: attributeName, value: attributeValue)
            })
        } else {
            self._pending?.append {
                try self.setAttribute(attributeName, attributeValue: attributeValue)
            }
        }
    }

    public func getAttribute(_ attributeName: String) -> YTextAttributeValue? {
        // TODO: This may be wrong
        return self.mapGet(attributeName) as? YTextAttributeValue
    }

    public func getAttributes() -> [String: YTextAttributeValue?] {
        // TODO: This may be wrong
        return self.mapGetAll() as? [String : (any YTextAttributeValue)?] ?? [:]
    }

    public override func _write(_ encoder: UpdateEncoder) {
        encoder.writeTypeRef(YTextRefID)
    }
}

public func readYText(_decoder: UpdateDecoder) -> YText {
    return YText()
}
