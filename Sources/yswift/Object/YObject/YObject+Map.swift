//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

extension YObject {
    func mapDelete(_ transaction: YTransaction, key: String) {
        self.storage[key]?.delete(transaction)
    }

    func mapSet(_ transaction: YTransaction, key: String, value: Any?) throws {
        let left = self.storage[key]
        let doc = transaction.doc
        let ownClientId = doc.clientID
        var content: any YContent
        if value == nil {
            content = YAnyContent([value])
        } else {
            if value! is Int || value! is NSDictionary || value! is Bool || value! is NSArray || value! is String {
                content = YAnyContent([value])
            } else if value! is Data {
                content = YBinaryContent(value as! Data)
            } else if value! is Doc {
                content = YDocumentContent(value as! Doc)
            } else {
                if value! is YObject {
                    content = YObjectContent(value as! YObject)
                } else {
                    throw YSwiftError.unexpectedContentType
                }
            }
        }
        let id = YID(client: ownClientId, clock: doc.store.getState(ownClientId))
        try YItem(id: id, left: left, origin: left?.lastID, right: nil, rightOrigin: nil, parent: .object(self), parentSub: key, content: content)
            .integrate(transaction: transaction, offset: 0)
    }

    func mapGet(_ key: String) -> Any? {
        let val = self.storage[key]
        return val != nil && !val!.deleted ? val!.content.values[val!.length - 1] : nil
    }

    func mapGetAll() -> [String: Any?] {
        var res: [String: Any?] = [:]
        self.storage.forEach({ key, value in
            if !value.deleted {
                res[key] = value.content.values[value.length - 1]
            }
        })
        return res
    }
    
    func mapHas(_ key: String) -> Bool {
        let val = self.storage[key]
        return val != nil && !val!.deleted
    }

    func mapGet(_ key: String, snapshot: YSnapshot) -> Any? {
        var v = self.storage[key]
        while (v != nil && (snapshot.stateVectors[v!.id.client] == nil || v!.id.clock >= (snapshot.stateVectors[v!.id.client] ?? 0))) {
            v = v!.left as? YItem
        }
        return v != nil && v!.isVisible(snapshot) ? v!.content.values[Int(v!.length) - 1] : nil
    }
}
