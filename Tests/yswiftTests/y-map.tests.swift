//
//  File.swift
//  
//
//  Created by yuki on 2023/03/22.
//

import XCTest
import Promise
@testable import yswift

private struct IntentionalError: Error {}

final class YMapTests: XCTestCase {
    
    func testSpecialForSwift_NilInInitialValues() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.map[0], map1 = test.map[1]
        
        try map0.setThrowingError("map", value: YMap(["nil": nil]))
        
        try test.connector.flushAllMessages()
        
        XCTAssertEqualJSON(
            try XCTUnwrap(map0["map"] as? YMap).toJSON(),
            ["nil": nil]
        )
        XCTAssertEqualJSON(
            try XCTUnwrap(map1["map"] as? YMap).toJSON(),
            ["nil": nil]
        )
    }
    
    func testSpecialForSwift_AssignNilToMap() throws {
        let test = try YTest<Any>(docs: 2)
        let docs = test.docs, map0 = test.map[0], map1 = test.map[1]
        
        try map0.setThrowingError("nil", value: nil)
        
        try test.connector.flushAllMessages()

        XCTAssertEqual(map0.count, 1)
        XCTAssertNil(map0["nil"])
        
        XCTAssertEqual(map1.count, 1)
        XCTAssertNil(map1["nil"])
        
        try YAssertEqualDocs(docs)
    }
    
    func testMapHavingIterableAsConstructorParamTests() throws {
        let test = try YTest<Any>(docs: 1)
        let map0 = test.map[0]
        
        let m1 = YMap([ "int": 1, "string": "hello" ])
        try map0.setThrowingError("m1", value: m1)
        XCTAssertEqual(try XCTUnwrap(m1["int"] as? Int), 1)
        XCTAssertEqual(try XCTUnwrap(m1["string"] as? String), "hello")
        
        let m2 = YMap([
            "object": ["x": 1],
            "boolean": true
        ])
        
        try map0.setThrowingError("m2", value: m2)
        XCTAssertEqual(try XCTUnwrap(m2["object"] as? [String: Int])["x"], 1)
        XCTAssertEqual(try XCTUnwrap(m2["boolean"] as? Bool), true)
        
        let dict = Dictionary(uniqueKeysWithValues: m1.map{ $0 } + m2)
        let m3 = YMap(dict)
        try map0.setThrowingError("m3", value: m3)
        XCTAssertEqual(try XCTUnwrap(m3["int"] as? Int), 1)
        XCTAssertEqual(try XCTUnwrap(m3["string"] as? String), "hello")
        XCTAssertEqual(try XCTUnwrap(m3["object"] as? [String: Int]), ["x": 1])
        XCTAssertEqual(try XCTUnwrap(m3["boolean"] as? Bool), true)
    }
    
    func testBasicMapTests() throws {
        let test = try YTest<Any>(docs: 3)
        
        let connector = test.connector, docs = test.docs, map0 = test.map[0], map1 = test.map[1], map2 = test.map[2]
        docs[2].disconnect()
        
        try map0.setThrowingError("nil", value: nil)
        try map0.setThrowingError("number", value: 1)
        try map0.setThrowingError("string", value: "hello Y")
        try map0.setThrowingError("object", value: ["key": [ "key2": "value" ]])
        try map0.setThrowingError("y-map", value: YMap())
        try map0.setThrowingError("boolean1", value: true)
        try map0.setThrowingError("boolean0", value: false)
        let map = try XCTUnwrap(map0["y-map"] as? YMap)
        try map.setThrowingError("y-array", value: YArray())
        let array = try XCTUnwrap(map["y-array"] as? YArray)
        try array.insert(0, at: 0)
        try array.insert(-1, at: 0)
        
        XCTAssertEqualJSON(map0["nil"], nil, "client 0 computed the change (nil)")
        XCTAssertEqualJSON(map0["number"], 1, "client 0 computed the change (number)")
        XCTAssertEqualJSON(map0["string"], "hello Y", "client 0 computed the change (string)")
        XCTAssertEqualJSON(map0["boolean0"], false, "client 0 computed the change (boolean)")
        XCTAssertEqualJSON(map0["boolean1"], true, "client 0 computed the change (boolean)")
        XCTAssertEqualJSON(map0["object"], ["key": ["key2": "value"]], "client 0 computed the change (object)")
        XCTAssertEqualJSON(((map0["y-map"] as? YMap)?["y-array"] as? YArray)?[0], -1, "client 0 computed the change (type)")
        XCTAssertEqualJSON(map0.count, 7, "client 0 map has correct size")
        
        try docs[2].connect()
        try connector.flushAllMessages()

        XCTAssertEqualJSON(map1["nil"], nil, "client 1 received the update (nil)")
        XCTAssertEqualJSON(map1["number"], 1, "client 1 received the update (number)")
        XCTAssertEqualJSON(map1["string"], "hello Y", "client 1 received the update (string)")
        XCTAssertEqualJSON(map1["boolean0"], false, "client 1 computed the change (boolean)")
        XCTAssertEqualJSON(map1["boolean1"], true, "client 1 computed the change (boolean)")
        XCTAssertEqualJSON(map1["object"], ["key": ["key2": "value"]], "client 1 received the update (object)")
        XCTAssertEqualJSON(((map1["y-map"] as? YMap)?["y-array"] as? YArray)?[0], -1, "client 1 computed the change (type)")
        XCTAssertEqualJSON(map1.count, 7, "client 1 map has correct size")

        // compare disconnected user
        XCTAssertEqualJSON(map2["nil"], nil, "client 2 received the update (nil) - was disconnected")
        XCTAssertEqualJSON(map2["number"], 1, "client 2 received the update (number) - was disconnected")
        XCTAssertEqualJSON(map2["string"], "hello Y", "client 2 received the update (string) - was disconnected")
        XCTAssertEqualJSON(map2["boolean0"], false, "client 2 computed the change (boolean)")
        XCTAssertEqualJSON(map2["boolean1"], true, "client 2 computed the change (boolean)")
        XCTAssertEqualJSON(map2["object"], ["key": ["key2": "value"]], "client 2 received the update (object) - was disconnected")
        XCTAssertEqualJSON(((map2["y-map"] as? YMap)?["y-array"] as? YArray)?[0], -1, "client 2 received the update (type) - was disconnected")
        XCTAssertEqualJSON(map2.count, 7, "client 2 map has correct size")
        
        try YAssertEqualDocs(docs)
    }
    
    func testGetAndSetOfMapProperty() throws {
        let test = try YTest<Any>(docs: 2)
        
        let connector = test.connector, docs = test.docs, map0 = test.map[0]
        
        try map0.setThrowingError("stuff", value: "stuffy")
//        map0.set("undefined", value: undefined) // No undefined in Swift
        try map0.setThrowingError("nil", value: nil)
        
        XCTAssertEqualJSON(map0["stuff"], "stuffy")

        try connector.flushAllMessages()

        for doc in docs {
            let u = try doc.getMap("map")
            XCTAssertEqualJSON(u["stuff"], "stuffy")
//            XCTAssertEqualJSON(u.get("undefined") == undefined, "undefined")
            XCTAssertEqualJSON(u["nil"], nil, "nil")
        }
        
        try YAssertEqualDocs(docs)
    }
    
    func testYmapSetsYmap() throws {
        let test = try YTest<Any>(docs: 2)
        
        let docs = test.docs, map0 = test.map[0]
        let map = YMap()
        try map0.setThrowingError("map", value: map)
        
        XCTAssert(map0["map"] as? AnyObject === map)
        try map.setThrowingError("one", value: 1)
        XCTAssertEqualJSON(map["one"], 1)
        
        try YAssertEqualDocs(docs)
    }

    func testYmapSetsYarray() throws {
        let test = try YTest<Any>(docs: 2)
        
        let docs = test.docs, map0 = test.map[0]
        let array = YArray()
        
        try map0.setThrowingError("array", value: array)
        XCTAssert(map0["array"] as? AnyObject === array)
        
        try array.insert(contentsOf: [1, 2, 3], at: 0)
        
        XCTAssertEqualJSON(map0.toJSON(), ["array": [1, 2, 3]])
        
        try YAssertEqualDocs(docs)
    }

    func testGetAndSetOfMapPropertySyncs() throws {
        let test = try YTest<Any>(docs: 2)
        let connector = test.connector, docs = test.docs, map0 = test.map[0]
        
        try map0.setThrowingError("stuff", value: "stuffy")
        XCTAssertEqualJSON(map0["stuff"], "stuffy")
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = try doc.getMap("map")
            XCTAssertEqualJSON(u["stuff"], "stuffy")
        }
        
        try YAssertEqualDocs(docs)
    }

    func testGetAndSetOfMapPropertyWithConflict() throws {
        let test = try YTest<Any>(docs: 3)
        
        let connector = test.connector, docs = test.docs, map0 = test.map[0], map1 = test.map[1]
        try map0.setThrowingError("stuff", value: "c0")
        try map1.setThrowingError("stuff", value: "c1")
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = try doc.getMap("map")
            XCTAssertEqualJSON(u["stuff"], "c1")
        }
        
        try YAssertEqualDocs(docs)
    }

    func testSizeAndDeleteOfMapProperty() throws {
        let test = try YTest<Any>(docs: 1)
        let map0 = test.map[0]
        
        try map0.setThrowingError("stuff", value: "c0")
        try map0.setThrowingError("otherstuff", value: "c1")
        XCTAssertEqual(map0.count, 2, "map size is \(map0.count) expected 2")
        
        try map0.removeValue(forKey: "stuff")
        XCTAssertEqual(map0.count, 1, "map size after delete is \(map0.count), expected 1")
        
        try map0.removeValue(forKey: "otherstuff")
        XCTAssertEqual(map0.count, 0, "map size after delete is \(map0.count), expected 0")
    }

    func testGetAndSetAndDeleteOfMapProperty() throws {
        let test = try YTest<Any>(docs: 3)
        
        let connector = test.connector, docs = test.docs, map0 = test.map[0], map1 = test.map[1]
        try map0.setThrowingError("stuff", value: "c0")
        try map1.setThrowingError("stuff", value: "c1")
        try map1.removeValue(forKey: "stuff")
        
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = try doc.getMap("map")
            XCTAssertNil(u["stuff"])
        }
        
        try YAssertEqualDocs(docs)
    }

    func testSetAndClearOfMapProperties() throws {
        let test = try YTest<Any>(docs: 1)
        
        let connector = test.connector, docs = test.docs, map0 = test.map[0]
        try map0.setThrowingError("stuff", value: "c0")
        try map0.setThrowingError("otherstuff", value: "c1")
        try map0.removeAll()
        
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = try doc.getMap("map")
            XCTAssertNil(u["stuff"])
            XCTAssertNil(u["otherstuff"])
            XCTAssert(u.count == 0, "map size after clear is \(u.count), expected 0")
        }
        
        try YAssertEqualDocs(docs)
    }

    func testSetAndClearOfMapPropertiesWithConflicts() throws {
        let test = try YTest<Any>(docs: 4)
        
        let connector = test.connector, docs = test.docs,
        map0 = test.map[0], map1 = test.map[1], map2 = test.map[2], map3 = test.map[3]
        
        try map0.setThrowingError("stuff", value: "c0")
        try map1.setThrowingError("stuff", value: "c1")
        try map1.setThrowingError("stuff", value: "c2")
        try map2.setThrowingError("stuff", value: "c3")
        
        try connector.flushAllMessages()
        
        try map0.setThrowingError("otherstuff", value: "c0")
        try map1.setThrowingError("otherstuff", value: "c1")
        try map2.setThrowingError("otherstuff", value: "c2")
        try map3.setThrowingError("otherstuff", value: "c3")
        try map3.removeAll()
        
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = try doc.getMap("map")
            XCTAssertNil(u["stuff"])
            XCTAssertNil(u["otherstuff"])
            XCTAssert(u.count == 0, "map size after clear is \(u.count), expected 0")
        }
        
        try YAssertEqualDocs(docs)
    }

    func testGetAndSetOfMapPropertyWithThreeConflicts() throws {
        let test = try YTest<Any>(docs: 3)
        let connector = test.connector, docs = test.docs, map0 = test.map[0], map1 = test.map[1], map2 = test.map[2]
        
        try map0.setThrowingError("stuff", value: "c0")
        try map1.setThrowingError("stuff", value: "c1")
        try map1.setThrowingError("stuff", value: "c2")
        try map2.setThrowingError("stuff", value: "c3")
        
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = try doc.getMap("map")
            XCTAssertEqualJSON(u["stuff"], "c3")
        }
        
        try YAssertEqualDocs(docs)
    }

    func testGetAndSetAndDeleteOfMapPropertyWithThreeConflicts() throws {
        let test = try YTest<Any>(docs: 4)
        let connector = test.connector, docs = test.docs, map0 = test.map[0], map1 = test.map[1], map2 = test.map[2], map3 = test.map[3]
        
        try map0.setThrowingError("stuff", value: "c0")
        try map1.setThrowingError("stuff", value: "c1")
        try map1.setThrowingError("stuff", value: "c2")
        try map2.setThrowingError("stuff", value: "c3")
        
        try connector.flushAllMessages()
        
        try map0.setThrowingError("stuff", value: "deleteme")
        try map1.setThrowingError("stuff", value: "c1")
        try map2.setThrowingError("stuff", value: "c2")
        try map3.setThrowingError("stuff", value: "c3")
        try map3.removeValue(forKey: "stuff")
        
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = try doc.getMap("map")
            XCTAssertNil(u["stuff"])
        }
        
        try YAssertEqualDocs(docs)
    }
    
    func testObserveDeepProperties() throws {
        let test = try YTest<Any>(docs: 4)
        let connector = test.connector, docs = test.docs, map1 = test.map[1], map2 = test.map[2], map3 = test.map[3]
        
        let _map1 = YMap()
        try map1.setThrowingError("map", value: _map1)
        
        var calls = 0
        var dmapid: YID?
        map1.observeDeep({ events, _ in
            try events.forEach({ event in
                let mevent = try XCTUnwrap(event as? YMapEvent)
                calls += 1
                
                XCTAssert(mevent.keysChanged.contains("deepmap"))
                XCTAssertEqual(mevent.path.count, 1)
                XCTAssertEqualJSON(mevent.path[0], "map")
                let emap = try XCTUnwrap(event.target as? YMap)
                dmapid = try XCTUnwrap(emap["deepmap"] as? YMap).item?.id
            })
        })
        
        try connector.flushAllMessages()
        
        let _map3 = try XCTUnwrap(map3["map"] as? YMap)
        try _map3.setThrowingError("deepmap", value: YMap())
        try connector.flushAllMessages()
        
        let _map2 = try XCTUnwrap(map2["map"] as? YMap)
        try _map2.setThrowingError("deepmap", value: YMap())
        try connector.flushAllMessages()
        
        let dmap1 = try XCTUnwrap(_map1["deepmap"] as? YMap)
        let dmap2 = try XCTUnwrap(_map2["deepmap"] as? YMap)
        let dmap3 = try XCTUnwrap(_map3["deepmap"] as? YMap)
        
        XCTAssertGreaterThan(calls, 0)
        XCTAssertEqual(dmap1.item?.id, dmap2.item?.id)
        XCTAssertEqual(dmap1.item?.id, dmap3.item?.id)
        XCTAssertEqual(dmap1.item?.id, dmapid)
        
        try YAssertEqualDocs(docs)
    }

    func testObserversUsingObservedeep() throws {
        let test = try YTest<Any>(docs: 2)
        let docs = test.docs, map0 = test.map[0]

        var pathes: [[PathElement]] = []
        var calls = 0
        
        map0.observeDeep{ events, _ in
            events.forEach{ event in
                pathes.append(event.path)
            }
            calls += 1
        }
        
        try map0.setThrowingError("map", value: YMap())
        let _map = try XCTUnwrap(map0["map"] as? YMap)
        try _map.setThrowingError("array", value: YArray())
        try XCTUnwrap(_map["array"] as? YArray).insert("content", at: 0)
        
        XCTAssertEqual(calls, 3)
        XCTAssertEqualJSON(pathes, [[], ["map"], ["map", "array"]])
        
        try YAssertEqualDocs(docs)
    }

    // TODO: Test events in Map
    private func compareEvent(_ event: YEvent?, keysChanged: Set<String?>, target: AnyObject) {
        guard let event = event as? YMapEvent else {
            return XCTFail()
        }
        XCTAssertEqual(event.keysChanged, keysChanged)
        XCTAssert(event.target === target)
        // TODO: compare more values
    }

    func testThrowsAddAndUpdateAndDeleteEvents() throws {
        let test = try YTest<Any>(docs: 2)
        let docs = test.docs, map0 = test.map[0]

        var event: YEvent?
        map0.observe{ e, _ in event = e }
        
        try map0.setThrowingError("stuff", value: 4)
        compareEvent(event, keysChanged: Set(["stuff"]), target: map0)
        
        // update, oldValue is in contents
        try map0.setThrowingError("stuff", value: YArray())
        compareEvent(event, keysChanged: Set(["stuff"]), target: map0)
        
        // update, oldValue is in opContents
        try map0.setThrowingError("stuff", value: 5)
        // delete
        try map0.removeValue(forKey: "stuff")
        compareEvent(event, keysChanged: Set(["stuff"]), target: map0)
        
        try YAssertEqualDocs(docs)
    }

    func testThrowsDeleteEventsOnClear() throws {
        let test = try YTest<Any>(docs: 2)
        let docs = test.docs, map0 = test.map[0]

        var event: YEvent?
        map0.observe{ e, _ in event = e }
        
        // set values
        try map0.setThrowingError("stuff", value: 4)
        try map0.setThrowingError("otherstuff", value: YArray())
        // clear
        try map0.removeAll()
        
        compareEvent(event, keysChanged: Set(["stuff", "otherstuff"]), target: map0)
        
        try YAssertEqualDocs(docs)
    }

    func testChangeEvent() throws {
        let test = try YTest<Any>(docs: 2)
        let docs = test.docs, map0 = test.map[0]

        var changes: YEventChange? = nil
        var keyChange: YEventKey? = nil
        
        map0.observe{ e, _ in changes = try e.changes() }
        
        try map0.setThrowingError("a", value: 1)
        keyChange = changes?.keys["a"]
        XCTAssertNotNil(changes)
        XCTAssertEqual(keyChange?.action, .add)
        XCTAssertNil(keyChange?.oldValue)
        
        try map0.setThrowingError("a", value: 2)
        keyChange = changes?.keys["a"]
        XCTAssertNotNil(changes)
        XCTAssertEqual(keyChange?.action, .update)
        XCTAssertEqualJSON(keyChange?.oldValue, 1)
        
        try docs[0].transact{ _ in
            try map0.setThrowingError("a", value: 3)
            try map0.setThrowingError("a", value: 4)
        }
        
        keyChange = changes?.keys["a"]
        XCTAssertNotNil(changes)
        XCTAssertEqual(keyChange?.action, .update)
        XCTAssertEqualJSON(keyChange?.oldValue, 2)
        
        try docs[0].transact{ _ in
            try map0.setThrowingError("b", value: 1)
            try map0.setThrowingError("b", value: 2)
        }
        
        keyChange = changes?.keys["b"]
        XCTAssertNotNil(changes)
        XCTAssertEqual(keyChange?.action, .add)
        XCTAssertNil(keyChange?.oldValue)
        
        try docs[0].transact{ _ in
            try map0.setThrowingError("c", value: 1)
            try map0.removeValue(forKey: "c")
        }
        XCTAssertNotNil(changes)
        XCTAssertEqual(changes?.keys.count, 0)
        
        try docs[0].transact{ _ in
            try map0.setThrowingError("d", value: 1)
            try map0.setThrowingError("d", value: 2)
        }
        
        keyChange = changes?.keys["d"]
        XCTAssertNotNil(changes)
        XCTAssertEqual(keyChange?.action, .add)
        XCTAssertNil(keyChange?.oldValue)
        
        try YAssertEqualDocs(docs)
    }

    func testYmapEventExceptionsShouldCompleteTransaction() throws {
        let doc = Doc()
        let map = try doc.getMap("map")

        var updateCalled = false
        var throwingObserverCalled = false
        var throwingDeepObserverCalled = false
        doc.on(Doc.On.update) { _ in updateCalled = true }

        func throwingObserver() throws {
            throwingObserverCalled = true
            throw IntentionalError()
        }

        func throwingDeepObserver() throws {
            throwingDeepObserverCalled = true
            throw IntentionalError()
        }

        map.observe{ _, _ in try throwingObserver() }
        map.observeDeep{ _, _ in try throwingDeepObserver() }

        XCTAssertThrowsError(try map.setThrowingError("y", value: "2"))
        
        XCTAssert(updateCalled)
        XCTAssert(throwingObserverCalled)
        XCTAssert(throwingDeepObserverCalled)

        // check if it works again
        updateCalled = false
        throwingObserverCalled = false
        throwingDeepObserverCalled = false
        XCTAssertThrowsError(try map.setThrowingError("z", value: "3"))

        XCTAssert(updateCalled)
        XCTAssert(throwingObserverCalled)
        XCTAssert(throwingDeepObserverCalled)

        XCTAssertEqualJSON(map["z"], "3")
    }
    

    private let mapTransactions: [(Doc, YTest<Any>, Any?) throws -> Void] = [
        { doc, test, _ in // set
            let key = test.gen.oneOf(["one", "two"])
            let value = test.gen.string()
            try doc.getMap("map").setThrowingError(key, value: value)
        },
        { doc, test, _ in // setType
            let key = test.gen.oneOf(["one", "two"])
            let type = test.gen.oneOf([YArray(), YMap()])
            try doc.getMap("map").setThrowingError(key, value: type)
            if let type = type as? YArray {
                try type.insert(contentsOf: [1, 2, 3, 4], at: 0)
            } else if let type = type as? YMap {
                try type.setThrowingError("deepkey", value: "deepvalue")
            }
        },
        { doc, test, _ in // delete
            let key = test.gen.oneOf(["one", "two"])
            try doc.getMap("map").removeValue(forKey: key)
        }
    ]

    func testRepeatGeneratingYmapTests10() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 6)
    }
    
    func testRepeatGeneratingYmapTests40() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 40)
    }

    func testRepeatGeneratingYmapTests42() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 42)
    }

    func testRepeatGeneratingYmapTests43() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 43)
    }

    func testRepeatGeneratingYmapTests44() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 44)
    }

    func testRepeatGeneratingYmapTests45() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 45)
    }

    func testRepeatGeneratingYmapTests46() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 46)
    }

    func testRepeatGeneratingYmapTests300() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 300)
    }

    func testRepeatGeneratingYmapTests400() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 400)
    }

    func testRepeatGeneratingYmapTests500() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 500)
    }

    func testRepeatGeneratingYmapTests600() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 600)
    }

    func testRepeatGeneratingYmapTests1000() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 1000)
    }

    func testRepeatGeneratingYmapTests1800() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 1800)
    }

//    func testRepeatGeneratingYmapTests5000() throws {
//        try XCTSkipIf(!isProductionTest)
//        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 5000)
//    }
//
//    func testRepeatGeneratingYmapTests10000() throws {
//        try XCTSkipIf(!isProductionTest)
//        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 10000)
//    }
//
//    func testRepeatGeneratingYmapTests100000() throws {
//        try XCTSkipIf(!isProductionTest)
//        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 100000)
//    }
}


// MARK: I don't understand why these two tests exist. (event.value and event.name must be undefined)

//    func testYmapEventHasCorrectValueWhenSettingAPrimitive() throws {
//        let test = try YTest<Any>(docs: 3)
//        let docs = test.docs, map0 = test.map[0]
//
//        var event: YMapEvent? = nil
//        map0.observe{ e, _ in event = try XCTUnwrap(e as? YMapEvent) }
//        try map0.set("stuff", value: 2)
//
//        XCTAssertEqual(event.value, event.target.get(event.name))
//
//        compare(users)
//    }
//    func testYmapEventHasCorrectValueWhenSettingAPrimitiveFromOtherUser() throws {
//        let { users, map0, map1, testConnector } = init(tc, { users: 3 })
//
//        var event: { [s: string]: Any } = {}
//        map0.observe(e -> {
//            event = e
//        })
//        map1.set("stuff", 2)
//        testConnector.flushAllMessages()
//        XCTAssertEqual(event.value, event.target.get(event.name))
//        compare(users)
//    }
