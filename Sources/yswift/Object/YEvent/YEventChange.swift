//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

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
