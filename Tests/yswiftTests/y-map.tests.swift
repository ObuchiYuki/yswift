//
//  File.swift
//  
//
//  Created by yuki on 2023/03/22.
//

import XCTest
import Promise
import yswift

final class YMapTests: XCTestCase {
    
    func testMapHavingIterableAsConstructorParamTests() throws {
        let test = try YTest<Any>(docs: 1)
        let map0 = test.map[0]
        
        let m1 = YMap([ "int": 1, "string": "hello" ])
        try map0.set("m1", value: m1)
        XCTAssertEqual(try XCTUnwrap(m1.get("int") as? Int), 1)
        XCTAssertEqual(try XCTUnwrap(m1.get("string") as? String), "hello")
        
        let m2 = YMap([
            "object": ["x": 1],
            "boolean": true
        ])
        
        try map0.set("m2", value: m2)
        XCTAssertEqual(try XCTUnwrap(m2.get("object") as? [String: Int])["x"], 1)
        XCTAssertEqual(try XCTUnwrap(m2.get("boolean") as? Bool), true)
        
        
        let dict = Dictionary(m1.entories().map{ $0 } + m2.entories(), uniquingKeysWith: { a, _ in a })
        let m3 = YMap(dict)
        try map0.set("m3", value: m3)
        XCTAssertEqual(try XCTUnwrap(m3.get("int") as? Int), 1)
        XCTAssertEqual(try XCTUnwrap(m3.get("string") as? String), "hello")
        XCTAssertEqual(try XCTUnwrap(m3.get("object") as? [String: Int]), ["x": 1])
        XCTAssertEqual(try XCTUnwrap(m3.get("boolean") as? Bool), true)
    }
    
    func testBasicMapTests() throws {
        let test = try YTest<Any>(docs: 3)
        
        let connector = test.connector, docs = test.docs, map0 = test.map[0], map1 = test.map[1], map2 = test.map[2]
        docs[2].disconnect()
        
        try map0.set("nil", value: nil)
        try map0.set("number", value: 1)
        try map0.set("string", value: "hello Y")
        try map0.set("object", value: ["key": [ "key2": "value" ]])
        try map0.set("y-map", value: YMap())
        try map0.set("boolean1", value: true)
        try map0.set("boolean0", value: false)
        let map = try XCTUnwrap(map0.get("y-map") as? YMap)
        try map.set("y-array", value: YArray())
        let array = try XCTUnwrap(map.get("y-array") as? YArray)
        try array.insert(0, [0])
        try array.insert(0, [-1])
                
        
        XCTAssertEqualJSON(map0.get("nil"), nil, "client 0 computed the change (nil)")
        XCTAssertEqualJSON(map0.get("number"), 1, "client 0 computed the change (number)")
        XCTAssertEqualJSON(map0.get("string"), "hello Y", "client 0 computed the change (string)")
        XCTAssertEqualJSON(map0.get("boolean0"), false, "client 0 computed the change (boolean)")
        XCTAssertEqualJSON(map0.get("boolean1"), true, "client 0 computed the change (boolean)")
        XCTAssertEqualJSON(map0.get("object"), ["key": ["key2": "value"]], "client 0 computed the change (object)")
        XCTAssertEqualJSON(((map0.get("y-map") as? YMap)?.get("y-array") as? YArray)?.get(0), -1, "client 0 computed the change (type)")
        XCTAssertEqualJSON(map0.size, 7, "client 0 map has correct size")
        
        try docs[2].connect()
        try connector.flushAllMessages()

        XCTAssertEqualJSON(map1.get("nil"), nil, "client 1 received the update (nil)")
        XCTAssertEqualJSON(map1.get("number"), 1, "client 1 received the update (number)")
        XCTAssertEqualJSON(map1.get("string"), "hello Y", "client 1 received the update (string)")
        XCTAssertEqualJSON(map1.get("boolean0"), false, "client 1 computed the change (boolean)")
        XCTAssertEqualJSON(map1.get("boolean1"), true, "client 1 computed the change (boolean)")
        XCTAssertEqualJSON(map1.get("object"), ["key": ["key2": "value"]], "client 1 received the update (object)")
        XCTAssertEqualJSON(((map1.get("y-map") as? YMap)?.get("y-array") as? YArray)?.get(0), -1, "client 1 computed the change (type)")
        XCTAssertEqualJSON(map1.size, 7, "client 1 map has correct size")

        // compare disconnected user
        XCTAssertEqualJSON(map2.get("nil"), nil, "client 2 received the update (nil) - was disconnected")
        XCTAssertEqualJSON(map2.get("number"), 1, "client 2 received the update (number) - was disconnected")
        XCTAssertEqualJSON(map2.get("string"), "hello Y", "client 2 received the update (string) - was disconnected")
        XCTAssertEqualJSON(map2.get("boolean0"), false, "client 2 computed the change (boolean)")
        XCTAssertEqualJSON(map2.get("boolean1"), true, "client 2 computed the change (boolean)")
        XCTAssertEqualJSON(map2.get("object"), ["key": ["key2": "value"]], "client 2 received the update (object) - was disconnected")
        XCTAssertEqualJSON(((map2.get("y-map") as? YMap)?.get("y-array") as? YArray)?.get(0), -1, "client 2 received the update (type) - was disconnected")
        XCTAssertEqualJSON(map2.size, 7, "client 2 map has correct size")
        
        try YAssertEqualDocs(docs)
    }
    
    func testGetAndSetOfMapProperty() throws {
        let test = try YTest<Any>(docs: 2)
        
        let connector = test.connector, docs = test.docs, map0 = test.map[0]
        
        try map0.set("stuff", value: "stuffy")
//        map0.set("undefined", value: undefined) // No undefined in Swift
        try map0.set("nil", value: nil)
        
        XCTAssertEqualJSON(map0.get("stuff"), "stuffy")

        try connector.flushAllMessages()

        for doc in docs {
            let u = try doc.getMap("map")
            XCTAssertEqualJSON(u.get("stuff"), "stuffy")
//            XCTAssertEqualJSON(u.get("undefined") == undefined, "undefined")
            XCTAssertEqualJSON(u.get("nil"), nil, "nil")
        }
        
        try YAssertEqualDocs(docs)
    }
    
    func testYmapSetsYmap() throws {
        let test = try YTest<Any>(docs: 2)
        
        let docs = test.docs, map0 = test.map[0]
        let map = YMap()
        try map0.set("map", value: map)
        
        XCTAssert(map0.get("map") as? AnyObject === map)
        try map.set("one", value: 1)
        XCTAssertEqualJSON(map.get("one"), 1)
        
        try YAssertEqualDocs(docs)
    }

    func testYmapSetsYarray() throws {
        let test = try YTest<Any>(docs: 2)
        
        let docs = test.docs, map0 = test.map[0]
        let array = YArray()
        
        try map0.set("array", value: array)
        XCTAssert(map0.get("array") as? AnyObject === array)
        
        try array.insert(0, [1, 2, 3])
        
        XCTAssertEqualJSON(map0.toJSON(), ["array": [1, 2, 3]])
        
        try YAssertEqualDocs(docs)
    }

    func testGetAndSetOfMapPropertySyncs() throws {
        let test = try YTest<Any>(docs: 2)
        let connector = test.connector, docs = test.docs, map0 = test.map[0]
        
        try map0.set("stuff", value: "stuffy")
        XCTAssertEqualJSON(map0.get("stuff"), "stuffy")
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = try doc.getMap("map")
            XCTAssertEqualJSON(u.get("stuff"), "stuffy")
        }
        
        try YAssertEqualDocs(docs)
    }

    func testGetAndSetOfMapPropertyWithConflict() throws {
        let test = try YTest<Any>(docs: 3)
        
        let connector = test.connector, docs = test.docs, map0 = test.map[0], map1 = test.map[1]
        try map0.set("stuff", value: "c0")
        try map1.set("stuff", value: "c1")
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = try doc.getMap("map")
            XCTAssertEqualJSON(u.get("stuff"), "c1")
        }
        
        try YAssertEqualDocs(docs)
    }

    func testSizeAndDeleteOfMapProperty() throws {
        let test = try YTest<Any>(docs: 1)
        let map0 = test.map[0]
        
        try map0.set("stuff", value: "c0")
        try map0.set("otherstuff", value: "c1")
        XCTAssertEqual(map0.size, 2, "map size is \(map0.size) expected 2")
        
        try map0.delete("stuff")
        XCTAssertEqual(map0.size, 1, "map size after delete is \(map0.size), expected 1")
        
        try map0.delete("otherstuff")
        XCTAssertEqual(map0.size, 0, "map size after delete is \(map0.size), expected 0")
    }

    func testGetAndSetAndDeleteOfMapProperty() throws {
        let test = try YTest<Any>(docs: 3)
        
        let connector = test.connector, docs = test.docs, map0 = test.map[0], map1 = test.map[1]
        try map0.set("stuff", value: "c0")
        try map1.set("stuff", value: "c1")
        try map1.delete("stuff")
        
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = try doc.getMap("map")
            XCTAssertNil(u.get("stuff"))
        }
        
        try YAssertEqualDocs(docs)
    }

    func testSetAndClearOfMapProperties() throws {
        let test = try YTest<Any>(docs: 1)
        
        let connector = test.connector, docs = test.docs, map0 = test.map[0]
        try map0.set("stuff", value: "c0")
        try map0.set("otherstuff", value: "c1")
        try map0.clear()
        
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = try doc.getMap("map")
            XCTAssertNil(u.get("stuff"))
            XCTAssertNil(u.get("otherstuff"))
            XCTAssert(u.size == 0, "map size after clear is \(u.size), expected 0")
        }
        
        try YAssertEqualDocs(docs)
    }

    func testSetAndClearOfMapPropertiesWithConflicts() throws {
        let test = try YTest<Any>(docs: 4)
        
        let connector = test.connector, docs = test.docs,
        map0 = test.map[0], map1 = test.map[1], map2 = test.map[2], map3 = test.map[3]
        
        try map0.set("stuff", value: "c0")
        try map1.set("stuff", value: "c1")
        try map1.set("stuff", value: "c2")
        try map2.set("stuff", value: "c3")
        
        try connector.flushAllMessages()
        
        try map0.set("otherstuff", value: "c0")
        try map1.set("otherstuff", value: "c1")
        try map2.set("otherstuff", value: "c2")
        try map3.set("otherstuff", value: "c3")
        try map3.clear()
        
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = try doc.getMap("map")
            XCTAssertNil(u.get("stuff"))
            XCTAssertNil(u.get("otherstuff"))
            XCTAssert(u.size == 0, "map size after clear is \(u.size), expected 0")
        }
        
        try YAssertEqualDocs(docs)
    }

//    func testGetAndSetOfMapPropertyWithThreeConflicts() throws {
//        let { testConnector, users, map0, map1, map2 } = init(tc, { users: 3 })
//        map0.set("stuff", "c0")
//        map1.set("stuff", "c1")
//        map1.set("stuff", "c2")
//        map2.set("stuff", "c3")
//        testConnector.flushAllMessages()
//        for ( let user of users) {
//            let u = user.getMap("map")
//            XCTAssertEqual(u.get("stuff"), "c3")
//        }
//        compare(users)
//    }
//
//    func testGetAndSetAndDeleteOfMapPropertyWithThreeConflicts() throws {
//        let { testConnector, users, map0, map1, map2, map3 } = init(tc, { users: 4 })
//        map0.set("stuff", "c0")
//        map1.set("stuff", "c1")
//        map1.set("stuff", "c2")
//        map2.set("stuff", "c3")
//        testConnector.flushAllMessages()
//        map0.set("stuff", "deleteme")
//        map1.set("stuff", "c1")
//        map2.set("stuff", "c2")
//        map3.set("stuff", "c3")
//        map3.delete("stuff")
//        testConnector.flushAllMessages()
//        for ( let user of users) {
//            let u = user.getMap("map")
//            XCTAssert(u.get("stuff") == undefined)
//        }
//        compare(users)
//    }
//
//    func testObserveDeepProperties() throws {
//        let { testConnector, users, map1, map2, map3 } = init(tc, { users: 4 })
//        let _map1 = map1.set("map", Map())
//        var calls = 0
//        var dmapid
//        map1.observeDeep(events -> {
//            events.forEach(event -> {
//                calls++
//                // @ts-ignore
//                XCTAssert(event.keysChanged.has("deepmap"))
//                XCTAssert(event.path.length == 1)
//                XCTAssert(event.path[0] == "map")
//                // @ts-ignore
//                dmapid = event.target.get("deepmap")._item.id
//            })
//        })
//        testConnector.flushAllMessages()
//        let _map3 = map3.get("map")
//        _map3.set("deepmap", Map())
//        testConnector.flushAllMessages()
//        let _map2 = map2.get("map")
//        _map2.set("deepmap", Map())
//        testConnector.flushAllMessages()
//        let dmap1 = _map1.get("deepmap")
//        let dmap2 = _map2.get("deepmap")
//        let dmap3 = _map3.get("deepmap")
//        XCTAssert(calls > 0)
//        XCTAssert(compareIDs(dmap1._item.id, dmap2._item.id))
//        XCTAssert(compareIDs(dmap1._item.id, dmap3._item.id))
//        // @ts-ignore we want the possibility of dmapid being undefined
//        XCTAssert(compareIDs(dmap1._item.id, dmapid))
//        compare(users)
//    }
//
//    func testObserversUsingObservedeep() throws {
//        let { users, map0 } = init(tc, { users: 2 })
//
//        let pathes: Array<Array<string|number>> = []
//        var calls = 0
//        map0.observeDeep(events -> {
//            events.forEach(event -> {
//                pathes.push(event.path)
//            })
//            calls++
//        })
//        map0.set("map", Map())
//        map0.get("map").set("array", Array())
//        map0.get("map").get("array").insert(0, ["content"])
//        XCTAssert(calls == 3)
//        XCTAssertEqual(pathes, [[], ["map"], ["map", "array"]])
//        compare(users)
//    }
//
//    // TODO: Test events in Map
//    /**
//     * @param {Object<string,Any>} is
//     * @param {Object<string,Any>} should
//     */
//    let compareEvent = (is: { [s: string]: Any }, should: { [s: string]: Any }) -> {
//        for ( let key in should) {
//            XCTAssertEqual(should[key], is[key])
//        }
//    }
//
//    func testThrowsAddAndUpdateAndDeleteEvents() throws {
//        let { users, map0 } = init(tc, { users: 2 })
//
//        var event: { [s: string]: Any } = {}
//        map0.observe(e -> {
//            event = e // just put it on event, should be thrown synchronously Anyway
//        })
//        map0.set("stuff", 4)
//        compareEvent(event, {
//        target: map0,
//        keysChanged: Set(["stuff"])
//        })
//        // update, oldValue is in contents
//        map0.set("stuff", Array())
//        compareEvent(event, {
//        target: map0,
//        keysChanged: Set(["stuff"])
//        })
//        // update, oldValue is in opContents
//        map0.set("stuff", 5)
//        // delete
//        map0.delete("stuff")
//        compareEvent(event, {
//        keysChanged: Set(["stuff"]),
//        target: map0
//        })
//        compare(users)
//    }
//
//    func testThrowsDeleteEventsOnClear() throws {
//        let { users, map0 } = init(tc, { users: 2 })
//
//        var event: { [s: string]: Any } = {}
//        map0.observe(e -> {
//            event = e // just put it on event, should be thrown synchronously Anyway
//        })
//        // set values
//        map0.set("stuff", 4)
//        map0.set("otherstuff", Array())
//        // clear
//        map0.clear()
//        compareEvent(event, {
//        keysChanged: Set(["stuff", "otherstuff"]),
//        target: map0
//        })
//        compare(users)
//    }
//
//    func testChangeEvent() throws {
//        let { map0, users } = init(tc, { users: 2 })
//
//        var changes: Any = nil
//
//        var keyChange: Any = nil
//        map0.observe(e -> {
//            changes = e.changes
//        })
//        map0.set("a", 1)
//        keyChange = changes.keys.get("a")
//        XCTAssert(changes != nil && keyChange.action == "add" && keyChange.oldValue == undefined)
//        map0.set("a", 2)
//        keyChange = changes.keys.get("a")
//        XCTAssert(changes != nil && keyChange.action == "update" && keyChange.oldValue == 1)
//        users[0].transact(() -> {
//            map0.set("a", 3)
//            map0.set("a", 4)
//        })
//        keyChange = changes.keys.get("a")
//        XCTAssert(changes != nil && keyChange.action == "update" && keyChange.oldValue == 2)
//        users[0].transact(() -> {
//            map0.set("b", 1)
//            map0.set("b", 2)
//        })
//        keyChange = changes.keys.get("b")
//        XCTAssert(changes != nil && keyChange.action == "add" && keyChange.oldValue == undefined)
//        users[0].transact(() -> {
//            map0.set("c", 1)
//            map0.delete("c")
//        })
//        XCTAssert(changes != nil && changes.keys.size == 0)
//        users[0].transact(() -> {
//            map0.set("d", 1)
//            map0.set("d", 2)
//        })
//        keyChange = changes.keys.get("d")
//        XCTAssert(changes != nil && keyChange.action == "add" && keyChange.oldValue == undefined)
//        compare(users)
//    }
//
//    func testYmapEventExceptionsShouldCompleteTransaction() throws {
//        let doc = Doc()
//        let map = doc.getMap("map")
//
//        var updateCalled = false
//        var throwingObserverCalled = false
//        var throwingDeepObserverCalled = false
//        doc.on("update", () -> {
//            updateCalled = true
//        })
//
//        let throwingObserver = () -> {
//            throwingObserverCalled = true
//            throw Error("Failure")
//        }
//
//        let throwingDeepObserver = () -> {
//            throwingDeepObserverCalled = true
//            throw Error("Failure")
//        }
//
//        map.observe(throwingObserver)
//        map.observeDeep(throwingDeepObserver)
//
//        t.fails(() -> {
//            map.set("y", "2")
//        })
//
//        XCTAssert(updateCalled)
//        XCTAssert(throwingObserverCalled)
//        XCTAssert(throwingDeepObserverCalled)
//
//        // check if it works again
//        updateCalled = false
//        throwingObserverCalled = false
//        throwingDeepObserverCalled = false
//        t.fails(() -> {
//            map.set("z", "3")
//        })
//
//        XCTAssert(updateCalled)
//        XCTAssert(throwingObserverCalled)
//        XCTAssert(throwingDeepObserverCalled)
//
//        XCTAssert(map.get("z") == "3")
//    }
//
//    func testYmapEventHasCorrectValueWhenSettingAPrimitive() throws {
//        let { users, map0 } = init(tc, { users: 3 })
//
//        var event: { [s: string]: Any } = {}
//        map0.observe(e -> {
//            event = e
//        })
//        map0.set("stuff", 2)
//        XCTAssertEqual(event.value, event.target.get(event.name))
//        compare(users)
//    }
//
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
//
//    let mapTransactions: Array<((arg0: Doc, arg1: prng.PRNG) -> void)> = [
//        func set(_ user, gen) {
//            let key = prng.oneOf(gen, ["one", "two"])
//            let value = prng.utf16String(gen)
//            user.getMap("map").set(key, value)
//        },
//        func setType(_ user, gen) {
//            let key = prng.oneOf(gen, ["one", "two"])
//            let type = prng.oneOf(gen, [Array(), Map()])
//            user.getMap("map").set(key, type)
//            if type instanceof Array {
//                type.insert(0, [1, 2, 3, 4])
//            } else {
//                type.set("deepkey", "deepvalue")
//            }
//        },
//        func _delete(_ user, gen) {
//            let key = prng.oneOf(gen, ["one", "two"])
//            user.getMap("map").delete(key)
//        }
//    ]
//
//    func testRepeatGeneratingYmapTests10() throws {
//        applyRandomTests(tc, mapTransactions, 3)
//    }
//
//    func testRepeatGeneratingYmapTests40() throws {
//        applyRandomTests(tc, mapTransactions, 40)
//    }
//
//    func testRepeatGeneratingYmapTests42() throws {
//        applyRandomTests(tc, mapTransactions, 42)
//    }
//
//    func testRepeatGeneratingYmapTests43() throws {
//        applyRandomTests(tc, mapTransactions, 43)
//    }
//
//    func testRepeatGeneratingYmapTests44() throws {
//        applyRandomTests(tc, mapTransactions, 44)
//    }
//
//    func testRepeatGeneratingYmapTests45() throws {
//        applyRandomTests(tc, mapTransactions, 45)
//    }
//
//    func testRepeatGeneratingYmapTests46() throws {
//        applyRandomTests(tc, mapTransactions, 46)
//    }
//
//    func testRepeatGeneratingYmapTests300() throws {
//        applyRandomTests(tc, mapTransactions, 300)
//    }
//
//    func testRepeatGeneratingYmapTests400() throws {
//        applyRandomTests(tc, mapTransactions, 400)
//    }
//
//    func testRepeatGeneratingYmapTests500() throws {
//        applyRandomTests(tc, mapTransactions, 500)
//    }
//
//    func testRepeatGeneratingYmapTests600() throws {
//        applyRandomTests(tc, mapTransactions, 600)
//    }
//
//    func testRepeatGeneratingYmapTests1000() throws {
//        applyRandomTests(tc, mapTransactions, 1000)
//    }
//
//    func testRepeatGeneratingYmapTests1800() throws {
//        applyRandomTests(tc, mapTransactions, 1800)
//    }
//
//    func testRepeatGeneratingYmapTests5000() throws {
//        t.skip(!t.production)
//        applyRandomTests(tc, mapTransactions, 5000)
//    }
//
//    func testRepeatGeneratingYmapTests10000() throws {
//        t.skip(!t.production)
//        applyRandomTests(tc, mapTransactions, 10000)
//    }
//
//    func testRepeatGeneratingYmapTests100000() throws {
//        t.skip(!t.production)
//        applyRandomTests(tc, mapTransactions, 100000)
//    }
//
}
