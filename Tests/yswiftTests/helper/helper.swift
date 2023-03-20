//
//  File.swift
//  
//
//  Created by yuki on 2023/03/18.
//

import Foundation
import XCTest
@testable import yswift

func XCTAssertEqualJSON(_ a: Any, _ b : Any, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    XCTAssert(equalJSON(a, b), "(\(a)) is not equal to (\(b)) - \(message())", file: file, line: line)
}

func broadcastMessage(_ y: TestDoc, _ m: Data) {
    if y.tc.onlineConnections.contains(y) {
        y.tc.onlineConnections.forEach{ remoteYInstance in
            if remoteYInstance != y {
                remoteYInstance._receive(m, remoteClient: y)
            }
        }
    }
}

typealias RandomGenerator = Ref<SeededRandomNumberGenerator>

struct TestEnvironment {
    let encodeStateAsUpdate: (Doc, Data) throws -> Data
    let mergeUpdates: ([Data]) throws -> Data
    let applyUpdate: (Doc, Data, Any?) throws -> Void
    let logUpdate: (Data) -> Void
    let updateEventName: Doc.EventName<(update: Data, origin: Any?, Transaction)>
    let diffUpdate: (Data, Data) throws -> Data
        
    private static let v1 = TestEnvironment(
        encodeStateAsUpdate: yswift.encodeStateAsUpdate,
        mergeUpdates: yswift.mergeUpdates,
        applyUpdate: yswift.applyUpdate,
        logUpdate: yswift.logUpdate,
        updateEventName: Doc.On.update,
        diffUpdate: yswift.diffUpdate
    )
    
    private static let v2 = TestEnvironment(
        encodeStateAsUpdate: { try encodeStateAsUpdateV2(doc: $0, encodedTargetStateVector: $1) },
        mergeUpdates: { try mergeUpdatesV2(updates: $0) },
        applyUpdate: { try applyUpdateV2(ydoc: $0, update: $1, transactionOrigin: $2) },
        logUpdate: { logUpdateV2($0) },
        updateEventName: Doc.On.updateV2,
        diffUpdate: { try diffUpdateV2(update: $0, sv: $1) }
    )
    
    static var usingV2 = false
    static var currentEnvironment = TestEnvironment.v1
    
    static func useV1() {
        self.usingV2 = false
        self.currentEnvironment = .v1
    }
    
    static func useV2() {
        // As syncProtocol dosen't support v2
        self.usingV2 = false
        self.currentEnvironment = .v1
    }
}

struct YTest<T> {
    let connector: TestConnector
    let docs: [TestDoc]
    let array: [YArray]
    let map: [YMap]
    let text: [YText]
    let testObjects: [T?]
    
    private init(connector: TestConnector, docs: [TestDoc], array: [YArray], map: [YMap], text: [YText], testObjects: [T?]) {
        self.connector = connector
        self.docs = docs
        self.array = array
        self.map = map
        self.text = text
        self.testObjects = testObjects
    }

    init(
        docs doccount: Int,
        randomGenerator: RandomGenerator = RandomGenerator(value: SeededRandomNumberGenerator(seed: 0)),
        initTestObject: ((TestDoc) -> T)? = nil
    ) throws {
        let connector = TestConnector(randomGenerator)
        
        var docs = [TestDoc]()
        var array = [YArray]()
        var map = [YMap]()
        var text = [YText]()
        
        for i in 0..<doccount {
            let doc = try TestDoc(userID: i, connector: connector)
            doc.clientID = i
            docs.append(doc)
            try array.append(doc.getArray("array"))
            try map.append(doc.getMap("map"))
            try text.append(doc.getText("text"))
        }
        
        try connector.syncAll()
        
        let testObjects = docs.map{ initTestObject?($0) }
                        
        self.init(
            connector: connector, docs: docs, array: array, map: map, text: text, testObjects: testObjects
        )
    }
    
    @discardableResult
    static func randomTests(
        randomGenerator: RandomGenerator,
        mods: [(Doc, RandomGenerator, T?) -> Void],
        iterations: Int,
        initTestObject: ((TestDoc) -> T)? = nil
    ) throws -> YTest<T> {
        let test = try YTest(docs: 6, randomGenerator: randomGenerator, initTestObject: initTestObject)
        let connector = test.connector, docs = test.docs
        
        for _ in 0..<iterations {
            if Int.random(in: 0..<100, using: &randomGenerator.value) <= 2 {
                if Bool.random(using: &randomGenerator.value) {
                    connector.disconnectRandom()
                } else {
                    try connector.reconnectRandom()
                }
            } else if Int.random(in: 0..<100, using: &randomGenerator.value) <= 1 {
                // 1% chance to flush all
                 try connector.flushAllMessages()
            } else if Int.random(in: 0..<100, using: &randomGenerator.value) <= 50 {
                // 50% chance to flush a random message
                try connector.flushRandomMessage()
            }
            let doc = Int.random(in: 0..<docs.count, using: &randomGenerator.value)
            let dotest = mods.randomElement(using: &randomGenerator.value)!
            
            dotest(docs[doc], randomGenerator, test.testObjects[doc])
        }
        
        try YAssertEqualDocs(docs)
        return test
    }
}

class TestDoc: Doc {
    var tc: TestConnector
    var userID: Int
    var receiving: [TestDoc: Ref<[Data]>] = [:]
    var updates: Ref<[Data]> = Ref(value: [])
    
    init(userID: Int, connector: TestConnector) throws {
        self.userID = userID
        self.tc = connector
        
        super.init()
        
        connector.connections.insert(self)
        
        self.on(TestEnvironment.currentEnvironment.updateEventName) { update, origin, _ in
            if (origin as? AnyObject) !== connector {
                let encoder = Lib0Encoder()
                Sync.writeUpdate(encoder: encoder, update: update)
                broadcastMessage(self, encoder.data)
            }
            self.updates.value.append(update)
        }
        try self.connect()
    }

    func disconnect() {
        self.receiving = [:]
        self.tc.onlineConnections.remove(self)
    }

    func connect() throws {
        if !self.tc.onlineConnections.contains(self) {
            self.tc.onlineConnections.insert(self)
            let encoder = Lib0Encoder()
            
            try Sync.writeSyncStep1(encoder: encoder, doc: self)
            
            broadcastMessage(self, encoder.data)
            
            try self.tc.onlineConnections.forEach({ remoteYInstance in
                if remoteYInstance !== self {
                    let encoder = Lib0Encoder()
                    try Sync.writeSyncStep1(encoder: encoder, doc: remoteYInstance)
                    self._receive(encoder.data, remoteClient: remoteYInstance)
                }
            })
        }
    }

    func _receive(_ message: Data, remoteClient: TestDoc) {
        self.receiving.setIfUndefined(remoteClient, .init(value: [])).value.append(message)
    }
}
 
class TestConnector: JSHashable {
    var connections = Set<TestDoc>()
    var onlineConnections = Set<TestDoc>()
    var randomGenerator: RandomGenerator
    
    init(_ randomGenerator: RandomGenerator) {
        self.connections = Set()
        self.onlineConnections = Set()
        self.randomGenerator = randomGenerator
    }

    @discardableResult
    func flushRandomMessage() throws -> Bool {
        let connections = self.onlineConnections.filter{ $0.receiving.count > 0 }
        
        guard let receiver = connections.first else {
            return false
        }
            
        // to remove randomness
        let sender = receiver.receiving.keys.min(by: { $0.clientID < $1.clientID })!
        let messages = receiver.receiving[sender]!
                
        let data = messages.isEmpty ? nil : messages.value.removeFirst()
        
        if messages.count == 0 {
            receiver.receiving.removeValue(forKey: sender)
        }
        
        guard let receivedData = data else { return try self.flushRandomMessage() }
        
        let encoder = Lib0Encoder()
                
        try Sync.readSyncMessage(
            decoder: Lib0Decoder(data: receivedData), encoder: encoder, doc: receiver, transactionOrigin: receiver.tc
        )
        
        if encoder.count > 0 { sender._receive(encoder.data, remoteClient: receiver) }
        
        return true
    }

    @discardableResult
    func flushAllMessages() throws -> Bool {
        var didSomething = false
        while try self.flushRandomMessage() {
            didSomething = true
        }
        return didSomething
    }

    func reconnectAll() throws {
        try self.connections.forEach{ try $0.connect() }
    }

    func disconnectAll() {
        self.connections.forEach{ $0.disconnect() }
    }

    func syncAll() throws {
        try self.reconnectAll()
        try self.flushAllMessages()
    }

    @discardableResult
    func disconnectRandom() -> Bool {
        if self.onlineConnections.isEmpty { return false }
        
        self.onlineConnections.randomElement(using: &self.randomGenerator.value)?.disconnect()
        
        return true
    }

    @discardableResult
    func reconnectRandom() throws -> Bool {
        var reconnectable = [TestDoc]()
        
        self.connections.forEach{
            if !self.onlineConnections.contains($0) {
                reconnectable.append($0)
            }
        }
        
        if reconnectable.isEmpty { return false }
        try reconnectable.randomElement(using: &self.randomGenerator.value)?.connect()
        return true
    }
}

func compareItemIDs(_ a: Item?, _ b: Item?) -> Bool {
    if a === b { return true }
    return a?.id == b?.id
}

// returns updated docs
@discardableResult
func YAssertEqualDocs(_ docs: [TestDoc]) throws -> [Doc] {
    try docs.forEach{ try $0.connect() }
    while try docs[0].tc.flushAllMessages() {}

    let mergedDocs = try docs.map{ doc in
        // swift add
        let ydoc = Doc()
        let update = try TestEnvironment.currentEnvironment.mergeUpdates(doc.updates.value)
        try TestEnvironment.currentEnvironment.applyUpdate(ydoc, update, nil)
        return ydoc
    }
    
    var docs = docs as [Doc]
    
    docs.append(contentsOf: mergedDocs)
    let userArrayValues = try XCTUnwrap(docs.map{ try $0.getArray("array").toJSON() } as? [[Any]])
    let userMapValues = try XCTUnwrap(docs.map{ try $0.getMap("map").toJSON() } as? [[String: Any]])
    let userTextValues = try XCTUnwrap(docs.map{ try $0.getText("text").toDelta() })
        
    for doc in docs {
        XCTAssertNil(doc.store.pendingDs)
        XCTAssertNil(doc.store.pendingStructs)
    }
    
    // Test Map iterator
    let ymapkeys = try docs[0].getMap("map").keys().map{ $0 }
    XCTAssertEqual(ymapkeys.count, userMapValues[0].count)
    
    ymapkeys.forEach{ key in
        XCTAssertNotNil(userMapValues[0][key])
    }
    
    var mapRes: [String: Any] = [:]
    for (k, v) in try docs[0].getMap("map").createMapIterator() {
        mapRes[k] = v is AbstractType ? (v as! AbstractType).toJSON() : v
    }
    
    XCTAssertEqualJSON(userMapValues[0], mapRes)
    
    // Compare all users
    for i in 0..<docs.count-1 {
        try XCTAssertEqual(userArrayValues[i].count, docs[i].getArray("array").length)
        
        XCTAssertEqualJSON(userArrayValues[i], userArrayValues[i + 1])
        XCTAssertEqualJSON(userMapValues[i], userMapValues[i + 1])
        XCTAssertEqual(
            userTextValues[i].map{ a in
                a.insert is String ? a.insert as! String : " "
            }.joined().count,
            try docs[i].getText("text").length
        )
        
        for (a, b) in zip(userTextValues[i], userTextValues[i+1]) {
            XCTAssertEqual(a, b)
        }
        
        try XCTAssertEqual(
            encodeStateVector(doc: docs[i]),
            encodeStateVector(doc: docs[i + 1])
        )
        try YAssertEqualDeleteSet(
            DeleteSet.createFromStructStore(docs[i].store),
            DeleteSet.createFromStructStore(docs[i + 1].store)
        )
        try YAssertEqualStructStore(docs[i].store, docs[i + 1].store)
    }
    
    try docs.forEach{ try $0.destroy() }
    
    return docs
}

func YAssertEqualStructStore(_ ss1: StructStore, _ ss2: StructStore) throws {
    XCTAssertEqual(ss1.clients.count, ss2.clients.count)
    
    for (client, structs1) in ss1.clients {
        let structs2 = try XCTUnwrap(ss2.clients[client]?.value)
        
        XCTAssertEqual(structs2.count, structs1.count)
        
        for i in 0..<structs1.count {
            let s1 = structs1[i]
            let s2 = structs2[i]
            if (
                type(of: s1) != type(of: s2)
                || s1.id != s2.id
                || s1.deleted != s2.deleted
                || s1.length != s2.length
            ) {
                XCTFail("Structs dont match")
            }
            if let s1 = s1 as? Item {
                guard let s2 = s2 as? Item else {
                    return XCTFail("Items dont match")
                }
                if (
                    !((s1.left == nil && s2.left == nil) || (s1.left != nil && s2.left != nil && (s1.left as! Item).lastID == (s2.left as! Item).lastID))
                    || !compareItemIDs((s1.right as? Item), (s2.right as? Item))
                    || s1.origin != s2.origin
                    || s1.rightOrigin != s2.rightOrigin
                    || s1.parentSub != s2.parentSub
                ) {
                    return XCTFail("Items dont match")
                }
                // make sure that items are connected correctly
                XCTAssert(s1.left == nil || (s1.left as? Item)?.right === s1)
                XCTAssert(s1.right == nil || (s1.right as? Item)?.left === s1)
                XCTAssert(s2.left == nil || (s2.left as? Item)?.right === s2)
                XCTAssert(s2.right == nil || (s2.right as? Item)?.left === s2)
            }
        }
    }
}

func YAssertEqualDeleteSet(_ ds1: DeleteSet, _ ds2: DeleteSet)  throws {
    XCTAssertEqual(ds1.clients.count, ds2.clients.count)
    
    try ds1.clients.forEach({ client, deleteItems1 in
        let deleteItems2 = try XCTUnwrap(ds2.clients[client])
        
        XCTAssertEqual(deleteItems1.count, deleteItems2.count)
        
        for i in 0..<deleteItems1.count {
            let di1 = deleteItems1[i]
            let di2 = deleteItems2[i]
            if di1.clock != di2.clock || di1.len != di2.len {
                XCTFail("DeleteSets dont match")
            }
        }
    })
}

