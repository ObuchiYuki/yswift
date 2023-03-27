//
//  File.swift
//  
//
//  Created by yuki on 2023/03/18.
//

import Foundation
import Promise

public class PermanentUserData {
    public var yusers: YMap // YMap<YMap<Any>> ...may be
    public var doc: Doc
    public var clients: [Int: String]
    public var dss: [String: DeleteSet]

    public init(doc: Doc, storeType: YMap?) throws {
        self.yusers = try storeType ?? doc.getMap("users")
        self.doc = doc
        self.clients = [:]
        self.dss = [String: DeleteSet]()
        
        func initUser(user: YMap, userDescription: String) throws {
            let ds = user.get("ds") as! YArray // <Data>
            let ids = user.get("ids") as! YArray // <Int> ...may be
            func addClientId(clientid: Int) {
                self.clients[clientid] = userDescription
            }
            
            ds.observe{ event, _ in
                try event.changes().added.forEach({ item in
                    try item.content.values.forEach({ encodedDs in
                        if encodedDs is Data {
                            self.dss[userDescription] = DeleteSet.mergeAll([
                                self.dss[userDescription] ?? DeleteSet(),
                                try DeleteSet.decode(decoder: YDeleteSetDecoderV1(LZDecoder(encodedDs as! Data)))
                            ])
                        }
                    })
                })
            }
            
            self.dss[userDescription] = DeleteSet.mergeAll(
                try ds.map{ data in
                    try DeleteSet.decode(decoder: YDeleteSetDecoderV1(LZDecoder(data as! Data)))
                }
            )
            
            ids.observe{ event, _ in
                try event.changes().added.forEach({ item in
                    item.content.values.forEach{
                        addClientId(clientid: $0 as! Int)
                    }
                })
            }
            
            ids.forEach{ i in
                addClientId(clientid: i as! Int)
            }
        }
        // observe users
        self.yusers.observe({ event, _ in
            try (event as! YMapEvent).keysChanged.forEach({ userDescription in
                try initUser(user: self.yusers.get(userDescription!) as! YMap, userDescription: userDescription!)
            })
        })
        // add intial data
        try self.yusers.forEach{ element, key, _ in
            try initUser(user: element as! YMap, userDescription: key)
        }
    }

    /**
     * @param {Doc} doc
     * @param {Int} clientid
     * @param {String} userDescription
     * @param {Object} conf
     * @param {function(Transaction, DeleteSet):Bool} [conf.filter]
     */
    public func setUserMapping(doc: Doc, clientid: Int, userDescription: String, filter: @escaping (Transaction, DeleteSet) -> Bool = {_, _ in true }) throws {
        let users = self.yusers
        var user = users.get(userDescription) as? YMap
        
        if user == nil {
            user = YMap()
            try user!.set("ids", value: YArray())
            try user!.set("ds", value: YArray())
            try users.set(userDescription, value: user!)
        }
        
        try (user!.get("ids") as! YArray).append(contentsOf: [clientid])
        
        users.observe{ _, _ in
            // may be for Dispatch
            Promise.wait(for: 0).tryPeek{
                let userOverwrite = users.get(userDescription) as? YMap
                if userOverwrite != user {
                    user = userOverwrite
                    
                    try self.clients.forEach({ clientid, _userDescription in
                        if userDescription == _userDescription {
                            try (user!.get("ids") as? YArray)?.append(contentsOf: [clientid])
                        }
                    })
                    let encoder = DSEncoderV1() as any DSEncoder
                    let ds = self.dss[userDescription]
                    if ds != nil {
                        try ds!.encode(into: encoder)
                        try (user!.get("ds") as! YArray).append(contentsOf: [encoder.toData()])
                    }
                }
            }
            .catch{ print($0) }
        }
        
        doc.on(Doc.On.afterTransaction) { transaction in
            Promise.wait(for: 0).tryPeek{
                let yds = user!.get("ds") as! YArray
                let ds = transaction.deleteSet
                if transaction.local && ds.clients.count > 0 && filter(transaction, ds) {
                    let encoder = DSEncoderV1()
                    try ds.encode(into: encoder)
                    try yds.append(contentsOf: [encoder.toData()])
                }
            }.catch{ print($0) }
        }
    }

    public func getUserByClientId(_ clientid: Int) -> Any? {
        return self.clients[clientid]
    }

    public func getUserByDeletedId(_ id: ID) -> String? {
        for (userDescription, ds) in self.dss {
            if ds.isDeleted(id) {
                return userDescription
            }
        }
        return nil
    }
}

