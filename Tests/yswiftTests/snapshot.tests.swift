import XCTest
import Promise
import yswift

final class SnapshotTests: XCTestCase {
    
//    func testBasicRestoreSnapshot() throws {
//        let doc = Doc(opts: DocOpts(gc: false))
//        try doc.getArray("array").insert(0, ["hello"])
//        let snap = Snapshot.snapshot(doc)
//        try doc.getArray("array").insert(1, ["world"])
//        
//        let docRestored = try snap.toDoc(doc)
//        
//        try XCTAssertEqualJSON(docRestored.getArray("array").toArray(), ["hello"])
//        try XCTAssertEqualJSON(doc.getArray("array").toArray(), ["hello", "world"])
//    }
    
//    func testEmptyRestoreSnapshot() throws {
//        let doc = Doc({ gc: false })
//        let snap = Snapshot.snapshot(doc)
//        snap.sv.set(9999, 0)
//        doc.getArray().insert(0, ["world"])
//
//        let docRestored = snap.toDoc(doc)
//
//        XCTAssertEqual(docRestored.getArray().toArray(), [])
//        XCTAssertEqual(doc.getArray().toArray(), ["world"])
//
//        // now self snapshot reflects the latest state. It shoult still work.
//        let snap2 = Snapshot.snapshot(doc)
//        let docRestored2 = snap2.toDoc(doc)
//        XCTAssertEqual(docRestored2.getArray().toArray(), ["world"])
//    }
//
//    func testRestoreSnapshotWithSubType() throws {
//        let doc = Doc({ gc: false })
//        doc.getArray("array").insert(0, [Map()])
//        let subMap = doc.getArray<Map<string>>("array").get(0)
//        subMap.set("key1", "value1")
//
//        let snap = Snapshot.snapshot(doc)
//        subMap.set("key2", "value2")
//
//        let docRestored = snap.toDoc(doc)
//
//        XCTAssertEqual(docRestored.getArray("array").toJSON(), [{
//        key1: "value1"
//        }])
//        XCTAssertEqual(doc.getArray("array").toJSON(), [{
//        key1: "value1",
//        key2: "value2"
//        }])
//    }
//
//    func testRestoreDeletedItem1() throws {
//        let doc = Doc({ gc: false })
//        doc.getArray("array").insert(0, ["item1", "item2"])
//
//        let snap = Snapshot.snapshot(doc)
//        doc.getArray("array").delete(0)
//
//        let docRestored = snap.toDoc(doc)
//
//        XCTAssertEqual(docRestored.getArray("array").toArray(), ["item1", "item2"])
//        XCTAssertEqual(doc.getArray("array").toArray(), ["item2"])
//    }
//
//    func testRestoreLeftItem() throws {
//        let doc = Doc({ gc: false })
//        doc.getArray("array").insert(0, ["item1"])
//        doc.getMap("map").set("test", 1)
//        doc.getArray("array").insert(0, ["item0"])
//
//        let snap = Snapshot.snapshot(doc)
//        doc.getArray("array").delete(1)
//
//        let docRestored = snap.toDoc(doc)
//
//        XCTAssertEqual(docRestored.getArray("array").toArray(), ["item0", "item1"])
//        XCTAssertEqual(doc.getArray("array").toArray(), ["item0"])
//    }
//
//    func testDeletedItemsBase() throws {
//        let doc = Doc({ gc: false })
//        doc.getArray("array").insert(0, ["item1"])
//        doc.getArray("array").delete(0)
//        let snap = Snapshot.snapshot(doc)
//        doc.getArray("array").insert(0, ["item0"])
//
//        let docRestored = snap.toDoc(doc)
//
//        XCTAssertEqual(docRestored.getArray("array").toArray(), [])
//        XCTAssertEqual(doc.getArray("array").toArray(), ["item0"])
//    }
//
//    func testDeletedItems2() throws {
//        let doc = Doc({ gc: false })
//        doc.getArray("array").insert(0, ["item1", "item2", "item3"])
//        doc.getArray("array").delete(1)
//        let snap = Snapshot.snapshot(doc)
//        doc.getArray("array").insert(0, ["item0"])
//
//        let docRestored = snap.toDoc(doc)
//
//        XCTAssertEqual(docRestored.getArray("array").toArray(), ["item1", "item3"])
//        XCTAssertEqual(doc.getArray("array").toArray(), ["item0", "item1", "item3"])
//    }
//
//    func testDependentChanges() throws {
//        let { array0, array1, testConnector } = init(tc, { users: 2 })
//
//        if !array0.doc {
//            throw Error("no document 0")
//        }
//        if !array1.doc {
//            throw Error("no document 1")
//        }
//
//        let doc0: Doc = array0.doc
//
//        let doc1: Doc = array1.doc
//
//        doc0.gc = false
//        doc1.gc = false
//
//        array0.insert(0, ["user1item1"])
//        testConnector.syncAll()
//        array1.insert(1, ["user2item1"])
//        testConnector.syncAll()
//
//        let snap = Snapshot.snapshot(array0.doc)
//
//        array0.insert(2, ["user1item2"])
//        testConnector.syncAll()
//        array1.insert(3, ["user2item2"])
//        testConnector.syncAll()
//
//        let docRestored0 = snap.toDoc(array0.doc)
//        XCTAssertEqual(docRestored0.getArray("array").toArray(), ["user1item1", "user2item1"])
//
//        let docRestored1 = snap.toDoc(array1.doc)
//        XCTAssertEqual(docRestored1.getArray("array").toArray(), ["user1item1", "user2item1"])
//    }
    
}
