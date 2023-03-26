import XCTest
import Promise
@testable import yswift

final class UpdatesTests: XCTestCase {
    func testMergeUpdates() throws {
        let test = try YTest<Any>(docs: 2)
        
        let docs = test.docs, array0 = test.array[0], array1 = test.array[1]

        try array0.insert(1, at: 0)
        try array1.insert(2, at: 0)

        let ndocs = try YAssertEqualDocs(docs)

        for env in YUpdateEnvironment.encoders {
            let merged = try env.docFromUpdates(ndocs.map{ $0 })
        
            try XCTAssertEqualJSON(
                array0.map{ $0 }, merged.getArray("array").map{ $0 }
            )
        }
    }
    
    func testKeyEncoding() throws {
        let test = try YTest<Any>(docs: 2)
        
        let docs = test.docs, text0 = test.text[0], text1 = test.text[1]

        try text0.insert(0, text: "a", attributes: ["i": true])
        try text0.insert(0, text: "b")
        try text0.insert(0, text: "c", attributes: ["i": true])
        
        let update = try docs[0].encodeStateAsUpdateV2()
        
        try applyUpdateV2(ydoc: docs[1], update: update)

        try XCTAssertEqual(text1.toDelta(), [
            YEventDelta(insert: "c", attributes: ["i": true]),
            YEventDelta(insert: "b"),
            YEventDelta(insert: "a", attributes: ["i": true]),
        ])

        try YAssertEqualDocs(docs)
    }
    
    func testMergeUpdates1() throws {
        for env in YUpdateEnvironment.encoders {
            print("== Using encoder: \(env.description) ==")
            let ydoc = Doc(opts: DocOpts(gc: false))
            var updates = [Data]()
            ydoc.on(env.updateEventName) { update, _, _ in updates.append(update) }

            let array = try ydoc.getArray()
            try array.insert(1, at: 0)
            try array.insert(2, at: 0)
            try array.insert(3, at: 0)
            try array.insert(4, at: 0)

            try checkUpdateCases(ydoc: ydoc, updates: updates, enc: env, hasDeletes: false)
        }
    }

    func testMergeUpdates2() throws {
        for env in [YUpdateEnvironment.v2] {
            print("== Using encoder: \(env.description) ==")
            let ydoc = Doc(opts: DocOpts(gc: false))
            var updates: [Data] = []
            ydoc.on(env.updateEventName) {
                update, _, _ in updates.append(update)
            }

            let array = try ydoc.getArray()
            try array.insert(contentsOf: [1, 2], at: 0)
            try array.remove(1, count: 1)
            try array.insert(contentsOf: [3, 4], at: 0)
            try array.remove(1, count: 2)
            
            try checkUpdateCases(ydoc: ydoc, updates: updates, enc: env, hasDeletes: true)
        }
    }

    func testMergePendingUpdates() throws {
        let yDoc = Doc()
        var serverUpdates: [Data] = []
        yDoc.on(Doc.On.update) { update, _, _ in
            serverUpdates.insert(update, at: serverUpdates.count)
        }
        let yText = try yDoc.getText("textBlock")
        try yText.applyDelta([ YEventDelta(insert: "r") ])
        try yText.applyDelta([ YEventDelta(insert: "o") ])
        try yText.applyDelta([ YEventDelta(insert: "n") ])
        try yText.applyDelta([ YEventDelta(insert: "e") ])
        try yText.applyDelta([ YEventDelta(insert: "n") ])

        let yDoc1 = Doc()
        try applyUpdate(ydoc: yDoc1, update: serverUpdates[0])
        let update1 = try yDoc1.encodeStateAsUpdate()

        let yDoc2 = Doc()
        try applyUpdate(ydoc: yDoc2, update: update1)
        try applyUpdate(ydoc: yDoc2, update: serverUpdates[1])
        let update2 = try yDoc2.encodeStateAsUpdate()

        let yDoc3 = Doc()
        try applyUpdate(ydoc: yDoc3, update: update2)
        try applyUpdate(ydoc: yDoc3, update: serverUpdates[3])
        let update3 = try yDoc3.encodeStateAsUpdate()

        let yDoc4 = Doc()
        try applyUpdate(ydoc: yDoc4, update: update3)
        try applyUpdate(ydoc: yDoc4, update: serverUpdates[2])
        let update4 = try yDoc4.encodeStateAsUpdate()

        let yDoc5 = Doc()
        try applyUpdate(ydoc: yDoc5, update: update4)
        try applyUpdate(ydoc: yDoc5, update: serverUpdates[4])
        _ = try yDoc5.encodeStateAsUpdate()

        let yText5 = try yDoc5.getText("textBlock")
        XCTAssertEqual(yText5.toString(), "nenor")
    }
    
    private func checkUpdateCases(ydoc: Doc, updates: [Data], enc: YUpdateEnvironment, hasDeletes: Bool) throws {
        var cases: [Data] = []

        // Case 1: Simple case, simply merge everything
        try cases.append(enc.mergeUpdates(updates))

        // Case 2: Overlapping updates
        try cases.append(enc.mergeUpdates([
            enc.mergeUpdates(updates[2...].map{ $0 }),
            enc.mergeUpdates(updates[..<2].map{ $0 })
        ]))

        // Case 3: Overlapping updates
        try cases.append(enc.mergeUpdates([
            enc.mergeUpdates(updates[2...].map{ $0 }),
            enc.mergeUpdates(updates[1..<3].map{ $0 }),
            updates[0]
        ]))

        // Case 4: Separated updates (containing skips)
        try cases.append(enc.mergeUpdates([
            enc.mergeUpdates([updates[0], updates[2]]),
            enc.mergeUpdates([updates[1], updates[3]]),
            enc.mergeUpdates(updates[4...].map{ $0 })
        ]))

        // Case 5: overlapping with mAny duplicates
        try cases.append(enc.mergeUpdates(cases))


        for mergedUpdates in cases {
            let merged = Doc(opts: DocOpts(gc: false))
            try enc.applyUpdate(merged, mergedUpdates, nil)
            try XCTAssertEqualJSON(merged.getArray().map{ $0 }, ydoc.getArray().map{ $0 })
            
            try XCTAssertEqual(
                enc.encodeStateVector_Doc(merged).map{ $0 },
                enc.encodeStateVectorFromUpdate(mergedUpdates).map{ $0 }
            )

            if enc.updateEventName.name != "update" {
                for j in 1..<updates.count {
                    let partMerged = try enc.mergeUpdates(updates[j...].map{ $0 })
                    let partMeta = try enc.parseUpdateMeta(partMerged)
                    let targetSV = try encodeStateVectorFromUpdateV2(update: mergeUpdatesV2(updates: updates[..<j].map{ $0 }))
                    let diffed = try enc.diffUpdate(mergedUpdates, targetSV)
                    let diffedMeta = try enc.parseUpdateMeta(diffed)
                    XCTAssertEqual(partMeta, diffedMeta)
                    do {
                        let decoder = LZDecoder(diffed)
                        let updateDecoder = try UpdateDecoderV2(decoder)
                        _ = try updateDecoder.readClientsStructRefs(doc: Doc())
                        let ds = try DeleteSet.decode(decoder: updateDecoder)
                        let updateEncoder = UpdateEncoderV2()
                        updateEncoder.restEncoder.writeUInt(0) // 0 structs
                        try ds.encode(into: updateEncoder)
                        let deletesUpdate = updateEncoder.toData()
                        let mergedDeletes = try mergeUpdatesV2(updates: [deletesUpdate, partMerged])
                        if !hasDeletes || enc !== YUpdateEnvironment.doc {
                            // deletes will almost definitely lead to different encoders because of the mergeStruct feature that is present in encDoc
                            XCTAssertEqual(diffed, mergedDeletes)
                        }
                    }
                }
            }

            let meta = try enc.parseUpdateMeta(mergedUpdates)
            meta.from.forEach{ client, clock in
                XCTAssert(clock == 0)
            }
            meta.to.forEach{ client, clock in
                let structs = merged.store.clients[client]?.value as! [Item]
                let lastStruct = structs[structs.count - 1]
                XCTAssert(lastStruct.id.clock + lastStruct.length == clock)
            }
        }
    }
}
