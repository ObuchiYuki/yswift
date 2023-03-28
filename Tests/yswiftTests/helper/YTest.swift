//
//  File.swift
//  
//
//  Created by yuki on 2023/03/22.
//

import Foundation
@testable import yswift

struct YTest<T> {
    let connector: TestConnector
    let docs: [TestDoc]
    let array: [YOpaqueArray]
    let map: [YOpaqueMap]
    let text: [YText]
    let testObjects: [T?]
    let gen: RandomGenerator
    let debugLog: Bool
    
    func swiftyArray<Element: YElement>(_: Element.Type, _ index: Int) -> YArray<Element> {
        YArray<Element>(opaque: self.array[index])
    }
    func swiftyMap<Value: YElement>(_: Value.Type, _ index: Int) -> YMap<Value> {
        YMap<Value>(opaque: self.map[index])
    }
    
    private init(connector: TestConnector, docs: [TestDoc], array: [YOpaqueArray], map: [YOpaqueMap], text: [YText], testObjects: [T?], gen: RandomGenerator, debugLog: Bool) {
        self.connector = connector
        self.docs = docs
        self.array = array
        self.map = map
        self.text = text
        self.testObjects = testObjects
        self.gen = gen
        self.debugLog = debugLog
    }

    init(
        docs doccount: Int,
        seed: Int32 = 0,
        debugLog: Bool = false,
        initTestObject: ((TestDoc) -> T)? = nil
    ) throws {
        let randomGenerator = RandomGenerator(seed: seed)
        let connector = TestConnector(randomGenerator)
        
        var docs = [TestDoc]()
        var array = [YOpaqueArray]()
        var map = [YOpaqueMap]()
        var text = [YText]()
        
        for i in 0..<doccount {
            let doc = try TestDoc(userID: i, connector: connector)
            doc.clientID = i
            docs.append(doc)
            try array.append(doc.getOpaqueArray("array"))
            try map.append(doc.getOpaqueMap("map"))
            try text.append(doc.getText("text"))
        }
        
        try connector.syncAll()
        
        let testObjects = docs.map{ initTestObject?($0) }
                        
        self.init(
            connector: connector, docs: docs, array: array, map: map, text: text, testObjects: testObjects, gen: randomGenerator, debugLog: debugLog
        )
    }
    
    func log(_ message: @autoclosure () -> String) {
        if debugLog {
            print(message())
        }
    }
    
    func randomTests(_ mods: [(YDocument, YTest<T>, T?) throws -> Void], iterations: Int, initTestObject: ((TestDoc) -> T)? = nil) throws {
        for _ in 0..<iterations {
            if gen.int(in: 0...100) <= 2 {
                if gen.bool() {
                    log("disconnectRandom")
                    self.connector.disconnectRandom()
                } else {
                    log("reconnectRandom")
                    try self.connector.reconnectRandom()
                }
            } else if gen.int(in: 0...100) <= 1 {
                // 1% chance to flush all
                log("== flushAllMessages ==")
                try self.connector.flushAllMessages()
                log("== flushAllMessages end ==")
            } else if gen.int(in: 0...100) <= 50 {
                // 50% chance to flush a random message
                log("flushRandomMessage")
                try self.connector.flushRandomMessage()
            }
            let doc = gen.int(in: 0...docs.count-1)
            let dotest = gen.oneOf(mods)
            
            try dotest(docs[doc], self, self.testObjects[doc])
        }
        
        try YAssertEqualDocs(docs)
    }
}
