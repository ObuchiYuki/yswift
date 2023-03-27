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

public struct YEventKey {
    public let action: YEventAction
    public let oldValue: Any?
    public let newValue: Any?
    
    init(action: YEventAction, oldValue: Any? = nil, newValue: Any? = nil) {
        self.action = action
        self.oldValue = oldValue
        self.newValue = newValue
    }
}

public struct YEventChange {
    public internal(set) var added: Set<Item>
    public internal(set) var deleted: Set<Item>
    public internal(set) var keys: [String: YEventKey]
    public internal(set) var delta: [YEventDelta]
    
    init(added: Set<Item>, deleted: Set<Item>, keys: [String : YEventKey], delta: [YEventDelta]) {
        self.added = added
        self.deleted = deleted
        self.keys = keys
        self.delta = delta
    }
}
