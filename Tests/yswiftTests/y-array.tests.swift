import XCTest
import Promise
@testable import yswift

final class YArrayTests: XCTestCase {
    func testBasicUpdate() throws {
        let doc1 = Doc()
        let doc2 = Doc()
        try doc1.getArray("array").insert(0, ["hi"])
        let update = try encodeStateAsUpdate(doc: doc1)
        try applyUpdate(ydoc: doc2, update: update)
        try XCTAssertEqualJSON(doc2.getArray("array").toArray(), ["hi"])
    }
    
    func testSlice() throws {
        let doc1 = Doc()
        let arr = try doc1.getArray("array")
        try arr.insert(0, [1, 2, 3])
        XCTAssertEqualJSON(arr.slice(0), [1, 2, 3])
        XCTAssertEqualJSON(arr.slice(1), [2, 3])
        XCTAssertEqualJSON(arr.slice(0, end: -1), [1, 2])
        try arr.insert(0, [0])
        XCTAssertEqualJSON(arr.slice(0), [0, 1, 2, 3])
        XCTAssertEqualJSON(arr.slice(0, end: 2), [0, 1])
    }

    func testArrayFrom() throws {
        let doc1 = Doc()
        let db1 = try doc1.getMap("root")
        let nestedArray1 = Array([0, 1, 2])
        try db1.set("array", value: nestedArray1)
        // ?
        XCTAssertEqual(nestedArray1, [0, 1, 2])
    }
    
    /**
     * Debugging yjs#297 - a critical bug connected to the search-marker approach
     *
     * @param {t.TestCase} tc
     */
    func testLengthIssue() throws {
        let doc1 = Doc()
        let arr = try doc1.getArray("array")
        try arr.push([0, 1, 2, 3])
        try arr.delete(0)
        try arr.insert(0, [0])
        XCTAssert(arr.length == arr.toArray().count)
        try doc1.transact{ _ in
            try arr.delete(1)
            XCTAssert(arr.length == arr.toArray().count)
            try arr.insert(1, [1])
            XCTAssert(arr.length == arr.toArray().count)
            try arr.delete(2)
            XCTAssert(arr.length == arr.toArray().count)
            try arr.insert(2, [2])
            XCTAssert(arr.length == arr.toArray().count)
        }
        XCTAssert(arr.length == arr.toArray().count)
        try arr.delete(1)
        XCTAssert(arr.length == arr.toArray().count)
        try arr.insert(1, [1])
        XCTAssert(arr.length == arr.toArray().count)
    }

    /**
     * Debugging yjs#314
     *
     * @param {t.TestCase} tc
     */
    func testLengthIssue2() throws {
        let doc = Doc()
        let next = try doc.getArray()
        try doc.transact({ _ in
            try next.insert(0, ["group2"])
        })
        try doc.transact({ _ in
            try next.insert(1, ["rectangle3"])
        })
        try doc.transact({ _ in
            try next.delete(0)
            try next.insert(0, ["rectangle3"])
        })
        try next.delete(1)
        try doc.transact({ _ in
            try next.insert(1, ["ellipse4"])
        })
        try doc.transact({ _ in
            try next.insert(2, ["ellipse3"])
        })
        try doc.transact({ _ in
            try next.insert(3, ["ellipse2"])
        })
        try doc.transact({ _ in
            try doc.transact({ _ in
                XCTAssertThrowsError(try next.insert(5, ["rectangle2"]))
                try next.insert(4, ["rectangle2"])
            })
            try doc.transact({ _ in
                // self should not throw an error message
                try next.delete(4)
            })
        })
        print(next.toArray())
    }

    func testDeleteInsert() throws {
        let test = try YTest<Any>(docs: 2)
        let docs = test.docs, array0 = test.array[0]
        
        try array0.delete(0, length: 0)
        
        print("Does not throw when deleting zero elements with position 0")
        XCTAssertThrowsError(try array0.delete(1, length: 1))
        try array0.insert(0, ["A"])
        try array0.delete(1, length: 0)
        
        print("Does not throw when deleting zero elements with valid position 1")
        try YAssertEqualDocs(docs)
    }
    
    func testInsertThreeElementsTryRegetProperty() throws {
        let test = try YTest<Any>(docs: 2)
        let connector = test.connector, docs = test.docs, array0 = test.array[0], array1 = test.array[1]
        
        try array0.insert(0, [1, true, false])
        XCTAssertEqualJSON(array0.toJSON(), [1, true, false], ".toJSON() works")
        
        try connector.flushAllMessages()
        XCTAssertEqualJSON(array1.toJSON(), [1, true, false], ".toJSON() works after sync")
        
        try YAssertEqualDocs(docs)
    }

    func testConcurrentInsertWithThreeConflicts() throws {
        let test = try YTest<Any>(docs: 3)
        let docs = test.docs, array0 = test.array[0], array1 = test.array[1], array2 = test.array[2]
        
        try array0.insert(0, [0])
        try array1.insert(0, [1])
        try array2.insert(0, [2])
        
        try YAssertEqualDocs(docs)
    }

    func testConcurrentInsertDeleteWithThreeConflicts() throws {
        let test = try YTest<Any>(docs: 3)
        let connector = test.connector, docs = test.docs, array0 = test.array[0], array1 = test.array[1], array2 = test.array[2]
        
        try array0.insert(0, ["x", "y", "z"])
        try connector.flushAllMessages()
        try array0.insert(1, [0])
        try array1.delete(0)
        try array1.delete(1, length: 1)
        try array2.insert(1, [2])
        try YAssertEqualDocs(docs)
    }

    func testInsertionsInLateSync() throws {
        let test = try YTest<Any>(docs: 3)
        
        let connector = test.connector, docs = test.docs, array0 = test.array[0], array1 = test.array[1], array2 = test.array[2]
        
        try array0.insert(0, ["x", "y"])
        try connector.flushAllMessages()
        
        docs[1].disconnect()
        docs[2].disconnect()
        
        try array0.insert(1, ["user0"])
        try array1.insert(1, ["user1"])
        try array2.insert(1, ["user2"])
        
        try docs[1].connect()
        try docs[2].connect()
        try connector.flushAllMessages()
        
        try YAssertEqualDocs(docs)
    }

    func testDisconnectReallyPreventsSendingMessages() throws {
        let test = try YTest<Any>(docs: 3)
        
        let connector = test.connector, docs = test.docs, array0 = test.array[0], array1 = test.array[1]
        
        try array0.insert(0, ["x", "y"])
        try connector.flushAllMessages()
        
        docs[1].disconnect()
        docs[2].disconnect()
        
        try array0.insert(1, ["user0"])
        try array1.insert(1, ["user1"])
        
        XCTAssertEqualJSON(array0.toJSON(), ["x", "user0", "y"])
        XCTAssertEqualJSON(array1.toJSON(), ["x", "user1", "y"])
        
        try docs[1].connect()
        try docs[2].connect()
        
        try YAssertEqualDocs(docs)
    }

    
    func testDeletionsInLateSync() throws {
        let test = try YTest<Any>(docs: 2)
        let connector = test.connector, users = test.docs, array0 = test.array[0], array1 = test.array[1]
        
        try array0.insert(0, ["x", "y"])
        try connector.flushAllMessages()
        
        users[1].disconnect()
        
        try array1.delete(1, length: 1)
        try array0.delete(0, length: 2)
        
        try users[1].connect()
        
        try YAssertEqualDocs(users)
    }

    func testInsertThenMergeDeleteOnSync() throws {
        let test = try YTest<Any>(docs: 2)
        let connector = test.connector, docs = test.docs, array0 = test.array[0], array1 = test.array[1]
        
        try array0.insert(0, ["x", "y", "z"])
        try connector.flushAllMessages()
        
        docs[0].disconnect()
        
        try array1.delete(0, length: 3)
        
        try docs[0].connect()
        
        try YAssertEqualDocs(docs)
    }

    func testInsertAndDeleteEvents() throws {
        let test = try YTest<Any>(docs: 2)
        let array0 = test.array[0], docs = test.docs
        var event: YEvent?
        
        array0.observe{ e, _ in event = e }
        try array0.insert(0, [0, 1, 2])
        XCTAssert(event != nil)
        
        event = nil
        try array0.delete(0)
        XCTAssert(event != nil)
        
        event = nil
        try array0.delete(0, length: 2)
        XCTAssert(event != nil)
        
        event = nil
        try YAssertEqualDocs(docs)
    }

    func testNestedObserverEvents() throws {
        let test = try YTest<Any>(docs: 2)
        let array0 = test.array[0], docs = test.docs
        var vals: [Int] = []
        
        array0.observe{ e, _ in
            if array0.length == 1 {
                try array0.insert(1, [1])
                vals.append(0)
            } else {
                vals.append(1)
            }
        }
        try array0.insert(0, [0])
        XCTAssertEqual(vals, [0, 1])
        XCTAssertEqualJSON(array0.toArray(), [0, 1])
        
        try YAssertEqualDocs(docs)
    }

    func testInsertAndDeleteEventsForTypes() throws {
        let test = try YTest<Any>(docs: 2)
        let array0 = test.array[0], docs = test.docs
        var event: YEvent?
        
        array0.observe{ e, _ in event = e }
        
        try array0.insert(0, [Array<Int>()])
        XCTAssert(event != nil)
        
        event = nil
        try array0.delete(0)
        XCTAssert(event != nil)
        
        event = nil
        try YAssertEqualDocs(docs)
    }

    /**
     * This issue has been reported in https://discuss.yjs.dev/t/order-in-which-events-yielded-by-observedeep-should-be-applied/261/2
     *
     * Deep observers generate multiple events. When an array added at item at, say, position 0,
     * and item 1 changed then the array-add event should fire first so that the change event
     * path is correct. A array binding might lead to an inconsistent state otherwise.
     *
     * @param {t.TestCase} tc
     */
    func testObserveDeepEventOrder() throws {
        let test = try YTest<Any>(docs: 2)
        let array0 = test.array[0], docs = test.docs

        var events: [YEvent] = []
        array0.observeDeep{ e, _ in events = e }
        
        try array0.insert(0, [YMap()])
        
        try docs[0].transact{ _ in
            try XCTUnwrap(array0.get(0) as? YMap).set("a", value: "a")
            try array0.insert(0, [0])
        }
        
        for i in 1..<events.count {
            XCTAssert(
                events[i-1].path.count <= events[i].path.count,
                "path size increases, fire top-level events first"
            )
        }
    }

    func testChangeEvent() throws {
        let test = try YTest<Any>(docs: 2)
        let array0 = test.array[0], docs = test.docs

        var changes: YEventChange? = nil
        array0.observe{ e, _ in changes = try e.changes() }
        
        let newArr = Array<Int>()
        try array0.insert(0, [newArr, 4, "dtrn"])
        
        var wchanges = try XCTUnwrap(changes)
        XCTAssertEqual(wchanges.added.count, 2)
        XCTAssertEqual(wchanges.deleted.count, 0)
        XCTAssertEqual(wchanges.delta, [YEventDelta(insert: [newArr, 4, "dtrn"])])
        
        
        changes = nil
        try array0.delete(0, length: 2)
        
        wchanges = try XCTUnwrap(changes)
        XCTAssertEqual(wchanges.added.count, 0)
        XCTAssertEqual(wchanges.deleted.count, 2)
        XCTAssertEqual(wchanges.delta, [YEventDelta(delete: 2)])
        
        changes = nil
        try array0.insert(1, [0.1])
        
        wchanges = try XCTUnwrap(changes)
        XCTAssertEqual(wchanges.added.count, 1)
        XCTAssertEqual(wchanges.deleted.count, 0)
        XCTAssertEqual(wchanges.delta, [YEventDelta(retain: 1), YEventDelta(insert: [0.1])])
        
        try YAssertEqualDocs(docs)
    }
    
//
//    func testInsertAndDeleteEventsForTypes2() throws {
//        let { array0, users } = init(tc, { users: 2 })
//
//        let events: Array<{ [s: String]: Any }> = []
//        array0.observe(e -> {
//            events.push(e)
//        })
//        array0.insert(0, ["hi", Map()])
//        XCTAssert(events.length == 1, "Event is triggered exactly once for insertion of two elements")
//        array0.delete(1)
//        XCTAssert(events.length == 2, "Event is triggered exactly once for deletion")
//        compare(users)
//    }
//
//    /**
//     * This issue has been reported here https://github.com/yjs/yjs/issues/155
//     * @param {t.TestCase} tc
//     */
//    func testNewChildDoesNotEmitEventInTransaction() throws {
//        let { array0, users } = init(tc, { users: 2 })
//        var fired = false
//        users[0].transact(() -> {
//            let newMap = Map()
//            newMap.observe(() -> {
//                fired = true
//            })
//            array0.insert(0, [newMap])
//            newMap.set("tst", 42)
//        })
//        XCTAssert(!fired, "Event does not trigger")
//    }
//
//    func testGarbageCollector() throws {
//        let { testConnector, users, array0 } = init(tc, { users: 3 })
//        array0.insert(0, ["x", "y", "z"])
//        testConnector.flushAllMessages()
//        users[0].disconnect()
//        array0.delete(0, 3)
//        users[0].connect()
//        testConnector.flushAllMessages()
//        compare(users)
//    }
//
//    func testEventTargetIsSetCorrectlyOnLocal() throws {
//        let { array0, users } = init(tc, { users: 3 })
//
//        var event: Any
//        array0.observe(e -> {
//            event = e
//        })
//        array0.insert(0, ["stuff"])
//        XCTAssert(event.target == array0, ""target" property is set correctly")
//        compare(users)
//    }
//
//    func testEventTargetIsSetCorrectlyOnRemote() throws {
//        let { testConnector, array0, array1, users } = init(tc, { users: 3 })
//
//        var event: Any
//        array0.observe(e -> {
//            event = e
//        })
//        array1.insert(0, ["stuff"])
//        testConnector.flushAllMessages()
//        XCTAssert(event.target == array0, ""target" property is set correctly")
//        compare(users)
//    }
//
//    func testIteratingArrayContainingTypes() throws {
//        let y = Doc()
//        let arr = y.getArray<Map<Int>>("arr")
//        let numItems = 10
//        for ( var i = 0; i < numItems; i++) {
//            let map = Map<Int>()
//            map.set("value", i)
//            arr.push([map])
//        }
//        var cnt = 0
//        for ( let item of arr) {
//            XCTAssert(item.get("value") == cnt++, "value is correct")
//        }
//        y.destroy()
//    }
//
//    var _uniqueNumber = 0
//    let getUniqueNumber = () -> _uniqueNumber++
//
//    let arrayTransactions: Array<((arg0: Doc, arg1: prng.PRNG, arg2: Any) -> Void)> = [
//        func insert(_ user, gen) {
//            let yarray = user.getArray<Int>("array")
//            let uniqueNumber = getUniqueNumber()
//            let content: [Int] = []
//            let len = prng.int32(gen, 1, 4)
//            for ( var i = 0; i < len; i++) {
//                content.push(uniqueNumber)
//            }
//            let pos = prng.int32(gen, 0, yarray.length)
//            let oldContent = yarray.toArray()
//            yarray.insert(pos, content)
//            oldContent.splice(pos, 0, ...content)
//            XCTAssertEqualArrays(yarray.toArray(), oldContent) // we want to make sure that fastSearch markers insert at the correct position
//        },
//        func insertTypeArray(_ user, gen) {
//            let yarray = user.getArray<Array<Int>>("array")
//            let pos = prng.int32(gen, 0, yarray.length)
//            yarray.insert(pos, [Array()])
//            let array2 = yarray.get(pos)
//            array2.insert(0, [1, 2, 3, 4])
//        },
//        func insertTypeMap(_ user, gen) {
//            let yarray = user.getArray<Map<Int>>("array")
//            let pos = prng.int32(gen, 0, yarray.length)
//            yarray.insert(pos, [Map()])
//            let map = yarray.get(pos)
//            map.set("someprop", 42)
//            map.set("someprop", 43)
//            map.set("someprop", 44)
//        },
//        func insertTypeNull(_ user, gen) {
//            let yarray = user.getArray("array")
//            let pos = prng.int32(gen, 0, yarray.length)
//            yarray.insert(pos, [nil])
//        },
//        func _delete(_ user, gen) {
//            let yarray = user.getArray("array")
//            let length = yarray.length
//            if length > 0 {
//                var somePos = prng.int32(gen, 0, length - 1)
//                var delLength = prng.int32(gen, 1, math.min(2, length - somePos))
//                if prng.bool(gen) {
//                    let type = yarray.get(somePos)
//                    if type instanceof Array && type.length > 0 {
//                        somePos = prng.int32(gen, 0, type.length - 1)
//                        delLength = prng.int32(gen, 0, math.min(2, type.length - somePos))
//                        type.delete(somePos, delLength)
//                    }
//                } else {
//                    let oldContent = yarray.toArray()
//                    yarray.delete(somePos, delLength)
//                    oldContent.splice(somePos, delLength)
//                    XCTAssertEqualArrays(yarray.toArray(), oldContent)
//                }
//            }
//        }
//    ]
//
//    func testRepeatGeneratingYarrayTests6() throws {
//        applyRandomTests(tc, arrayTransactions, 6)
//    }
//
//    func testRepeatGeneratingYarrayTests40() throws {
//        applyRandomTests(tc, arrayTransactions, 40)
//    }
//
//    func testRepeatGeneratingYarrayTests42() throws {
//        applyRandomTests(tc, arrayTransactions, 42)
//    }
//
//    func testRepeatGeneratingYarrayTests43() throws {
//        applyRandomTests(tc, arrayTransactions, 43)
//    }
//
//    func testRepeatGeneratingYarrayTests44() throws {
//        applyRandomTests(tc, arrayTransactions, 44)
//    }
//
//    func testRepeatGeneratingYarrayTests45() throws {
//        applyRandomTests(tc, arrayTransactions, 45)
//    }
//
//    func testRepeatGeneratingYarrayTests46() throws {
//        applyRandomTests(tc, arrayTransactions, 46)
//    }
//
//    func testRepeatGeneratingYarrayTests300() throws {
//        applyRandomTests(tc, arrayTransactions, 300)
//    }
//
//    func testRepeatGeneratingYarrayTests400() throws {
//        applyRandomTests(tc, arrayTransactions, 400)
//    }
//
//    func testRepeatGeneratingYarrayTests500() throws {
//        applyRandomTests(tc, arrayTransactions, 500)
//    }
//
//    func testRepeatGeneratingYarrayTests600() throws {
//        applyRandomTests(tc, arrayTransactions, 600)
//    }
//
//    func testRepeatGeneratingYarrayTests1000() throws {
//        applyRandomTests(tc, arrayTransactions, 1000)
//    }
//
//    func testRepeatGeneratingYarrayTests1800() throws {
//        applyRandomTests(tc, arrayTransactions, 1800)
//    }
//
//    func testRepeatGeneratingYarrayTests3000() throws {
//        t.skip(!t.production)
//        applyRandomTests(tc, arrayTransactions, 3000)
//    }
//
//    func testRepeatGeneratingYarrayTests5000() throws {
//        t.skip(!t.production)
//        applyRandomTests(tc, arrayTransactions, 5000)
//    }
//
//    func testRepeatGeneratingYarrayTests30000() throws {
//        t.skip(!t.production)
//        applyRandomTests(tc, arrayTransactions, 30000)
//    }
    
}
