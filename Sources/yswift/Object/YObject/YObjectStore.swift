//
//  File.swift
//  
//
//  Created by yuki on 2023/04/01.
//

import Promise

final class YObjectStore {
    
    static let shared = YObjectStore()
    
    private var objectTable = [YObjectID: YObject]()
    private var pendingObjects = [YObjectID: [Promise<YObject, Never>]]()
    
    func register(_ object: YObject) {
        guard let id = object.objectID else {
            assertionFailure("This object has no objectID yet.")
            return
        }
        
        self.objectTable[id] = object
        
        if let pendings = self.pendingObjects.removeValue(forKey: id) {
            for pending in pendings {
                pending.fullfill(object)
            }
        }
    }
    
    func object(for id: YObjectID) -> Promise<YObject, Never> {
        if let object = self.objectTable[id] { return .fullfill(object) }
        print("== THIS ==")
        
        if self.pendingObjects[id] == nil { self.pendingObjects[id] = [] }
        let promise = Promise<YObject, Never>()
        self.pendingObjects[id]!.append(promise)
        return promise
    }
}
