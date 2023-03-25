//
//  File.swift
//  
//
//  Created by yuki on 2023/03/22.
//

import Foundation
import XCTest
import yswift

class TestDoc: Doc {
    var connector: TestConnector
    var userID: Int
    var receiving: [TestDoc: Ref<[Data]>] = [:]
    var updates: Ref<[Data]> = Ref(value: [])
    
    init(userID: Int, connector: TestConnector) throws {
        self.userID = userID
        self.connector = connector
        
        super.init()
        
        connector.connections.insert(self)
        
        self.on(YTestEnvironment.currentEnvironment.updateEventName) { update, origin, _ in
            if (origin as? AnyObject) !== connector {
                let encoder = LZEncoder()
                Sync.writeUpdate(encoder: encoder, update: update)
                self.broadcastMessage(encoder.data)
            }
            self.updates.value.append(update)
        }
        try self.connect()
    }

    func disconnect() {
        self.receiving = [:]
        self.connector.onlineConnections.remove(self)
    }

    func connect() throws {
        if !self.connector.onlineConnections.contains(self) {
            self.connector.onlineConnections.insert(self)
            let encoder = LZEncoder()
            
            try Sync.writeSyncStep1(encoder: encoder, doc: self)
            
            self.broadcastMessage(encoder.data)
            
            try self.connector.onlineConnections.forEach({ remoteYInstance in
                if remoteYInstance !== self {
                    let encoder = LZEncoder()
                    try Sync.writeSyncStep1(encoder: encoder, doc: remoteYInstance)
                    self._receive(encoder.data, remoteClient: remoteYInstance)
                }
            })
        }
    }

    func _receive(_ message: Data, remoteClient: TestDoc) {
        self.receiving.setIfUndefined(remoteClient, .init(value: [])).value.append(message)
    }
    
    private func broadcastMessage(_ m: Data) {
        if self.connector.onlineConnections.contains(self) {
            self.connector.onlineConnections.forEach{ remoteYInstance in
                if remoteYInstance != self {
                    remoteYInstance._receive(m, remoteClient: self)
                }
            }
        }
    }
}
 
