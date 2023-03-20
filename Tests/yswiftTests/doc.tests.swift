import XCTest
import Promise
@testable import yswift

final class DocTests: XCTestCase {
    
    func testAfterTransactionRecursion() throws { // xml -> array
        let ydoc = Doc()
        let ymap = try ydoc.getArray("")
        ydoc.on(Doc.On.afterTransaction) { tr in
            if tr.origin as! String == "test" {
                _ = ymap.toJSON()
            }
        }
        try ydoc.transact({ _ in
            for _ in 0..<1500  { // as Swift slow in DEBUG mode
                try ymap.push([YText("a")])
            }
        }, origin: "test")
    }

    func testOriginInTransaction() throws {
        let doc = Doc()
        let ytext = try doc.getText("")
        var origins = [String]()
        
        doc.on(Doc.On.afterTransaction) { tr in
            guard let origin = tr.origin as? String else { return XCTFail("No a string.") }
            
            origins.append(origin)
            
            if origins.count <= 1 {
                _ = try ytext.toDelta(Snapshot.snapshot(doc))
                try doc.transact({ _ in
                    try ytext.insert(0, text: "a")
                }, origin: "nested")
            }
        }
        
        try doc.transact({ _ in
            try ytext.insert(0, text: "0")
        }, origin: "first")
        
        XCTAssertEqual(origins, ["first", "cleanup", "nested"])
    }

    func testClientIdDuplicateChange() throws {
        let doc1 = Doc()
        doc1.clientID = 0
        let doc2 = Doc()
        doc2.clientID = 0
        XCTAssertEqual(doc2.clientID, doc1.clientID)
        try doc1.getArray("a").insert(0, [1, 2])
        try applyUpdate(ydoc: doc2, update: encodeStateAsUpdate(doc: doc1))
        XCTAssertNotEqual(doc2.clientID, doc1.clientID)
    }

    func testGetTypeEmptyId() throws {
        let doc1 = Doc(opts: .init(cliendID: 100))
        try doc1.getText("").insert(0, text: "h")
        try doc1.getText("").insert(1, text: "i")
                
        let doc2 = Doc(opts: .init(cliendID: 101))
        
        let update = try encodeStateAsUpdate(doc: doc1)
                
        try applyUpdate(ydoc: doc2, update: update)
        
        try XCTAssertEqual(doc2.getText("").toString(), "hi")
        try XCTAssertEqual(doc2.getText("").toString(), "hi")
    }

    func testToJSON() throws {
        let doc = Doc()
        XCTAssertTrue(doc.toJSON().isEmpty, "doc.toJSON yields empty object")

        let arr = try doc.getArray("array")
        try arr.push(["test1"])

        let map = try doc.getMap("map")
        try map.set("k1", value: "v1")
        let map2 = YMap()
        try map.set("k2", value: map2)
        try map2.set("m2k1", value: "m2v1")

        XCTAssertEqual(doc.toJSON() as NSDictionary, [
            "array": [ "test1" ],
            "map": [
                "k1": "v1",
                "k2": [
                    "m2k1": "m2v1"
                ]
                
            ]
        ], "doc.toJSON has array and recursive map")
    }

        
    func testSubdoc() throws {
        let doc = Doc()
        try doc.load() // doesn"t do Anything
        
        do {
            var event: [Set<String>]? = nil
            
            doc.on(Doc.On.subdocs) { subdocs, _ in
                event = [
                    Set(subdocs.added.map{ $0.guid }),
                    Set(subdocs.removed.map{ $0.guid }),
                    Set(subdocs.loaded.map{ $0.guid })
                ]
            }
            
            let subdocs = try doc.getMap("mysubdocs")
            let docA = Doc(opts: .init(guid: "a"))
            try docA.load()
            try subdocs.set("a", value: docA)
            
            XCTAssertEqual(event, [["a"], [], ["a"]])

            event = nil
            try (subdocs.get("a") as! Doc).load()
            XCTAssertNil(event)

            event = nil
            try (subdocs.get("a") as! Doc).destroy()
            XCTAssertEqual(event, [["a"], ["a"], []])
            try (subdocs.get("a") as! Doc).load()
            XCTAssertEqual(event, [[], [], ["a"]])

            try subdocs.set("b", value: Doc(opts: .init(guid: "a", shouldLoad: false)))
            XCTAssertEqual(event, [["a"], [], []])
            try (subdocs.get("b") as! Doc).load()
            XCTAssertEqual(event, [[], [], ["a"]])

            let docC = Doc(opts: .init(guid: "c"))
            try docC.load()
            try subdocs.set("c", value: docC)
            XCTAssertEqual(event, [["c"], [], ["c"]])

            XCTAssertEqual(doc.getSubdocGuids(), ["a", "c"])
        }

        let doc2 = Doc()
        do {
            XCTAssertTrue(doc2.getSubdocs().isEmpty)
            var event: [Set<String>]? = nil
            
            doc2.on(Doc.On.subdocs) { subdocs, _ in
                event = [
                    Set(subdocs.added.map{ $0.guid }),
                    Set(subdocs.removed.map{ $0.guid }),
                    Set(subdocs.loaded.map{ $0.guid })
                ]
            }
            
            try applyUpdate(ydoc: doc2, update: encodeStateAsUpdate(doc: doc))
            XCTAssertEqual(event, [["a", "a", "c"], [], []])

            try (doc2.getMap("mysubdocs").get("a") as! Doc).load()
            XCTAssertEqual(event, [[], [], ["a"]])

            XCTAssertEqual(doc2.getSubdocGuids(), ["a", "c"])

            try doc2.getMap("mysubdocs").delete("a")
            XCTAssertEqual(event, [[], ["a"], []])
            XCTAssertEqual(doc2.getSubdocGuids(), ["a", "c"])
        }
    }

    func testSubdocLoadEdgeCases() throws {
        let ydoc = Doc()
        let yarray = try ydoc.getArray("") // [Doc]
        let subdoc1 = Doc()
        var lastEvent: Doc.On.SubDocEvent? = nil
        
        ydoc.on(Doc.On.subdocs) { event, _ in
            lastEvent = event
        }
        try yarray.insert(0, [subdoc1])
        XCTAssert(subdoc1.shouldLoad)
        XCTAssert(subdoc1.autoLoad == false)
        try XCTAssert(XCTUnwrap(lastEvent).loaded.contains(subdoc1))
        try XCTAssert(XCTUnwrap(lastEvent).added.contains(subdoc1))
        
        // destroy and check whether lastEvent adds it again to added (it shouldn"t)
        try subdoc1.destroy()
        let subdoc2 = try XCTUnwrap(yarray.get(0) as? Doc)
        XCTAssert(subdoc1 != subdoc2)
        try XCTAssert(XCTUnwrap(lastEvent).added.contains(subdoc2))
        try XCTAssert(!XCTUnwrap(lastEvent).loaded.contains(subdoc2))
        // load
        try subdoc2.load()
        try XCTAssert(!XCTUnwrap(lastEvent).added.contains(subdoc2))
        try XCTAssert(XCTUnwrap(lastEvent).loaded.contains(subdoc2))
        // apply from remote
        let ydoc2 = Doc()
        ydoc2.on(Doc.On.subdocs) { event, _ in
            lastEvent = event
        }
        try applyUpdate(ydoc: ydoc2, update: encodeStateAsUpdate(doc: ydoc))
        let subdoc3 = try XCTUnwrap(try ydoc2.getArray("").get(0) as? Doc)
        XCTAssert(subdoc3.shouldLoad == false)
        XCTAssert(subdoc3.autoLoad == false)
        try XCTAssert(XCTUnwrap(lastEvent).added.contains(subdoc3))
        try XCTAssert(!XCTUnwrap(lastEvent).loaded.contains(subdoc3))
        // load
        try subdoc3.load()
        XCTAssert(subdoc3.shouldLoad)
        try XCTAssert(!XCTUnwrap(lastEvent).added.contains(subdoc3))
        try XCTAssert(XCTUnwrap(lastEvent).loaded.contains(subdoc3))
    }

    func testSubdocLoadEdgeCasesAutoload() throws {
        let ydoc = Doc()
        let yarray = try ydoc.getArray("") // [Doc]
        let subdoc1 = Doc(opts: .init(autoLoad: true))
        
        var lastEvent: Doc.On.SubDocEvent? = nil
        ydoc.on(Doc.On.subdocs) { event, _ in
            lastEvent = event
        }
        
        try yarray.insert(0, [subdoc1])
        
        
        XCTAssertTrue(subdoc1.shouldLoad)
        XCTAssertTrue(subdoc1.autoLoad)
        try XCTAssert(XCTUnwrap(lastEvent).loaded.contains(subdoc1))
        try XCTAssert(XCTUnwrap(lastEvent).added.contains(subdoc1))
        
        // destroy and check whether lastEvent adds it again to added (it shouldn"t)
        try subdoc1.destroy()
        let subdoc2 = try XCTUnwrap(yarray.get(0) as? Doc)
        XCTAssertNotIdentical(subdoc1, subdoc2)
        try XCTAssert(XCTUnwrap(lastEvent).added.contains(subdoc2))
        try XCTAssert(!XCTUnwrap(lastEvent).loaded.contains(subdoc2))
                
        // load
        try subdoc2.load()
        try XCTAssert(!XCTUnwrap(lastEvent).added.contains(subdoc2))
        try XCTAssert(XCTUnwrap(lastEvent).loaded.contains(subdoc2))
        
        // apply from remote
        let ydoc2 = Doc()
        ydoc2.on(Doc.On.subdocs) { event, _ in
            lastEvent = event
        }
        let update = try encodeStateAsUpdate(doc: ydoc)
        try applyUpdate(ydoc: ydoc2, update: update)
        let subdoc3 = try XCTUnwrap(ydoc2.getArray("").get(0) as? Doc)
        XCTAssert(subdoc1.shouldLoad)
        XCTAssert(subdoc1.autoLoad)
        try XCTAssert(XCTUnwrap(lastEvent).added.contains(subdoc3))
        try XCTAssert(XCTUnwrap(lastEvent).loaded.contains(subdoc3))
    }

    func testSubdocsUndo() throws {
        let ydoc = Doc()
        let elems = try ydoc.getArray()
        let undoManager = UndoManager(typeScope: elems, options: .init())
        let subdoc = Doc()
        try elems.insert(0, [subdoc])
        try undoManager.undo()
        try undoManager.redo()
        XCTAssert(elems.length == 1)
    }

    func testLoadDocsEvent() async throws {
        let ydoc = Doc()
        XCTAssert(ydoc.isLoaded == false)
        var loadedEvent = false
        ydoc.on(Doc.On.load) {
            loadedEvent = true
        }
        try ydoc.emit(Doc.On.load, ())
        await ydoc.whenLoaded.value()
        
        XCTAssert(loadedEvent)
        XCTAssert(ydoc.isLoaded)
    }

    func testSyncDocsEvent() async throws {
        let ydoc = Doc()
        XCTAssertFalse(ydoc.isLoaded)
        XCTAssertFalse(ydoc.isSynced)
        var loadedEvent = false
        ydoc.once(Doc.On.load) {
            loadedEvent = true
        }
        var syncedEvent = false
        ydoc.once(Doc.On.sync) { isSynced in
            syncedEvent = true
            XCTAssertTrue(isSynced)
        }
        try ydoc.emit(Doc.On.sync, true)
        
        await ydoc.whenLoaded.value()
        
        let oldWhenSynced = ydoc.whenSynced
        
        await ydoc.whenSynced.value()
        
        XCTAssert(loadedEvent)
        XCTAssert(syncedEvent)
        XCTAssert(ydoc.isLoaded)
        XCTAssert(ydoc.isSynced)
        var loadedEvent2 = false
        ydoc.on(Doc.On.load) {
            loadedEvent2 = true
        }
        var syncedEvent2 = false
        ydoc.on(Doc.On.sync) { isSynced in
            syncedEvent2 = true
            XCTAssertFalse(isSynced)
        }
        try ydoc.emit(Doc.On.sync, false)
        XCTAssert(!loadedEvent2)
        XCTAssert(syncedEvent2)
        XCTAssert(ydoc.isLoaded)
        XCTAssert(!ydoc.isSynced)
        XCTAssert(ydoc.whenSynced.state.isSettled != oldWhenSynced?.state.isSettled)
    }
}
