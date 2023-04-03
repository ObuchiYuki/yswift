//
//  File.swift
//  
//
//  Created by yuki on 2023/04/03.
//

import Foundation

extension YObject {
    public func smartCopy() -> Self {
        // [old:new]
        let table = RefDictionary<YObjectID, YObjectID>()
        let writers = RefDictionary<YObjectID, (YObjectID) -> ()>()
        YObject.initContext = .smartcopy(table, writers)
        
        let copied = self.copy()
        
        for (oldID, writer) in writers {
            let newID = table[oldID] ?? oldID
            writer(newID)
        }
        
        return copied
    }
}
