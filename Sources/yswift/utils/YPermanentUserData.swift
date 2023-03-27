//
//  File.swift
//  
//
//  Created by yuki on 2023/03/18.
//

import Foundation
import Promise

public class YPermanentUserData {
    public var yusers: YMap // YMap<YMap<Any>> ...may be
    public var doc: Doc
    public var clients: [Int: String]
    var dss: [String: YDeleteSet]

    public init(doc: Doc, storeType: YMap?) throws {
        self.yusers = try storeType ?? doc.getMap("users")
        self.doc = doc
        self.clients = [:]
        self.dss = [String: YDeleteSet]()
        
        func initUser(user: YMap, userDescription: String) throws {
            let ds = user["ds"] as! YArray // <Data>
            let ids = user["ids"] as! YArray // <Int> ...may be
            func addClientId(clientid: Int) {
                self.clients[clientid] = userDescription
            }
            
            ds.observe{ event, _ in
                try event.changes().added.forEach({ item in
                    try item.content.values.forEach({ encodedDs in
                        if encodedDs is Data {
                            self.dss[userDescription] = YDeleteSet.mergeAll([
                                self.dss[userDescription] ?? YDeleteSet(),
                                try YDeleteSet.decode(decoder: YDeleteSetDecoderV1(LZDecoder(encodedDs as! Data)))
                            ])
                        }
                    })
                })
            }
            
            self.dss[userDescription] = YDeleteSet.mergeAll(
                try ds.map{ data in
                    try YDeleteSet.decode(decoder: YDeleteSetDecoderV1(LZDecoder(data as! Data)))
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
                try initUser(user: self.yusers[userDescription!] as! YMap, userDescription: userDescription!)
            })
        })
        // add intial data
        try self.yusers.forEach{ key, value in
            try initUser(user: value as! YMap, userDescription: key)
        }
    }

    /**
     * @param {Doc} doc
     * @param {Int} clientid
     * @param {String} userDescription
     * @param {Object} conf
     * @param {function(Transaction, DeleteSet):Bool} [conf.filter]
     */
    public func setUserMapping(doc: Doc, clientid: Int, userDescription: String, filter: @escaping (YTransaction, YDeleteSet) -> Bool = {_, _ in true }) throws {
        let users = self.yusers
        var user = users[userDescription] as? YMap
        
        if user == nil {
            user = YMap()
            user!["ids"] = YArray()
            user!["ds"] = YArray()
            users[userDescription] = user!
        }
        
        try (user!["ids"] as! YArray).append(contentsOf: [clientid])
        
        users.observe{ _, _ in
            // may be for Dispatch
            Promise.wait(for: 0).tryPeek{
                let userOverwrite = users[userDescription] as? YMap
                if userOverwrite != user {
                    user = userOverwrite
                    
                    try self.clients.forEach({ clientid, _userDescription in
                        if userDescription == _userDescription {
                            try (user!["ids"] as? YArray)?.append(contentsOf: [clientid])
                        }
                    })
                    let encoder = YDeleteSetEncoderV1() as any YDeleteSetEncoder
                    let ds = self.dss[userDescription]
                    if ds != nil {
                        try ds!.encode(into: encoder)
                        try (user!["ds"] as! YArray).append(contentsOf: [encoder.toData()])
                    }
                }
            }
            .catch{ print($0) }
        }
        
        doc.on(Doc.On.afterTransaction) { transaction in
            Promise.wait(for: 0).tryPeek{
                let yds = user!["ds"] as! YArray
                let ds = transaction.deleteSet
                if transaction.local && ds.clients.count > 0 && filter(transaction, ds) {
                    let encoder = YDeleteSetEncoderV1()
                    try ds.encode(into: encoder)
                    try yds.append(contentsOf: [encoder.toData()])
                }
            }.catch{ print($0) }
        }
    }

    public func getUserByClientId(_ clientid: Int) -> Any? {
        return self.clients[clientid]
    }

    public func getUserByDeletedId(_ id: YID) -> String? {
        for (userDescription, ds) in self.dss {
            if ds.isDeleted(id) {
                return userDescription
            }
        }
        return nil
    }
}

