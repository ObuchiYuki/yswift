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
    var added: Set<YItem>
    var deleted: Set<YItem>
    var keys: [String: YEventKey]
    var delta: [YEventDelta]
    
    init(added: Set<YItem>, deleted: Set<YItem>, keys: [String : YEventKey], delta: [YEventDelta]) {
        self.added = added
        self.deleted = deleted
        self.keys = keys
        self.delta = delta
    }
}
