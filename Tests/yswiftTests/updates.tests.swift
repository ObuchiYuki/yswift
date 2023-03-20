import XCTest
import Promise
@testable import yswift

struct UpdateEnvironment {
    let mergeUpdates: (_ updates: [Data]) throws -> Data
    let encodeStateAsUpdate: (_ doc: Doc, _ encodedTargetStateVector: Data?) throws -> Data
    let applyUpdate: (_ ydoc: Doc, _ update: Data, _ transactionOrigin: Any?) throws -> Void
    let logUpdate: (_ update: Data) -> Void
    let parseUpdateMeta: (_ update: Data) throws -> UpdateMeta
    let encodeStateVectorFromUpdate: (_ update: Data) throws -> Data
    let encodeStateVector_Doc: (_ doc: Doc) throws -> Data
    let encodeStateVector_SV: (_ doc: [Int: Int]) throws -> Data
    let updateEventName: Doc.EventName<(update: Data, origin: Any?, Transaction)>
    let description: String
    let diffUpdate: (_ update: Data, _ sv: Data) throws -> Data
    
    static let v1 = UpdateEnvironment(
        mergeUpdates: { try yswift.mergeUpdates(updates: $0) },
        encodeStateAsUpdate: { try yswift.encodeStateAsUpdate(doc: $0, encodedTargetStateVector: $1) },
        applyUpdate: { try yswift.applyUpdate(ydoc: $0, update: $1, transactionOrigin: $2) },
        logUpdate: { yswift.logUpdate($0) },
        parseUpdateMeta: { try yswift.parseUpdateMeta(update: $0) },
        encodeStateVectorFromUpdate: { try yswift.encodeStateVectorFromUpdate(update: $0) },
        encodeStateVector_Doc: { try encodeStateVector(doc: $0) },
        encodeStateVector_SV: { try encodeStateVector(doc: $0) },
        updateEventName: Doc.On.update,
        description: "V1",
        diffUpdate: { try yswift.diffUpdate(update: $0, sv: $1) }
    )
    
    static let v2 = UpdateEnvironment(
        mergeUpdates: { try mergeUpdatesV2(updates: $0) },
        encodeStateAsUpdate: { try encodeStateAsUpdateV2(doc: $0, encodedTargetStateVector: $1) },
        applyUpdate: { try applyUpdateV2(ydoc: $0, update: $1, transactionOrigin: $2) },
        logUpdate: { logUpdateV2($0) },
        parseUpdateMeta: { try parseUpdateMetaV2(update: $0) },
        encodeStateVectorFromUpdate: { try encodeStateVectorFromUpdateV2(update: $0) },
        encodeStateVector_Doc: { try encodeStateVector(doc: $0) },
        encodeStateVector_SV: { try encodeStateVector(doc: $0) },
        updateEventName: Doc.On.updateV2,
        description: "V2",
        diffUpdate: { try diffUpdateV2(update: $0, sv: $1) }
    )
    
    static let doc = UpdateEnvironment(
        mergeUpdates: { updates in
            let ydoc = Doc(opts: DocOpts(gc: false))
            try updates.forEach({ update in
                try applyUpdateV2(ydoc: ydoc, update: update)
            })
            return try encodeStateAsUpdateV2(doc: ydoc)
        },
        encodeStateAsUpdate: { try encodeStateAsUpdateV2(doc: $0, encodedTargetStateVector: $1) },
        applyUpdate: { try applyUpdateV2(ydoc: $0, update: $1, transactionOrigin: $2) },
        logUpdate: { logUpdateV2($0) },
        parseUpdateMeta: { try parseUpdateMetaV2(update: $0) },
        encodeStateVectorFromUpdate: { try encodeStateVectorFromUpdateV2(update: $0) },
        encodeStateVector_Doc: { try encodeStateVector(doc: $0) },
        encodeStateVector_SV: { try encodeStateVector(doc: $0) },
        updateEventName: Doc.On.updateV2,
        description: "Merge via Doc",
        diffUpdate: { update, sv in
            let ydoc = Doc(opts: DocOpts(gc: false))
            try applyUpdateV2(ydoc: ydoc, update: update)
            return try encodeStateAsUpdateV2(doc: ydoc, encodedTargetStateVector: sv)
        }
    )
    
    static let encoders = [UpdateEnvironment.v1, .v2, .doc]
    
    func docFromUpdates(_ docs: [Doc]) throws -> Doc {
        let updates = try docs.map{
            try self.encodeStateAsUpdate($0, nil)
        }
                
        let ydoc = Doc()
        try self.applyUpdate(ydoc, self.mergeUpdates(updates), nil)
        return ydoc
    }
}


final class updatesTests: XCTestCase {
    func testMergeUpdates() throws {
        let test = try YTest<Any>(docs: 2)
        
        let docs = test.docs, array0 = test.array[0], array1 = test.array[1]

        try array0.insert(0, content: [1])
        try array1.insert(0, content: [2])

        try YAssertEqualDocs(docs)

        for env in UpdateEnvironment.encoders {
            let merged = try env.docFromUpdates(docs.map{ $0 })
        
            try XCTAssertEqualJSON(
                array0.toArray(), merged.getArray("array").toArray()
            )
        }
    }
    
    func testKeyEncoding() throws {
        let test = try YTest<Any>(docs: 2)
        
        let docs = test.docs, text0 = test.text[0], text1 = test.text[1]

        try text0.insert(0, text: "a", attributes: Ref(value: ["i": true]))
        try text0.insert(0, text: "b")
        try text0.insert(0, text: "c", attributes: Ref(value: ["i": true]))
        
        let update = try encodeStateAsUpdateV2(doc: docs[0])
        
        try applyUpdateV2(ydoc: docs[1], update: update)

        try XCTAssertEqual(text1.toDelta(), [
            YEventDelta(insert: "c", attributes: Ref(value: ["i": true])),
            YEventDelta(insert: "b"),
            YEventDelta(insert: "a", attributes: Ref(value: ["i": true])),
        ])

        try YAssertEqualDocs(docs)
    }
    
    
//
//    /**
//     * @param {Doc} ydoc
//     * @param {Array<Data>} updates - expecting at least 4 updates
//     * @param {Enc} enc
//     * @param {Bool} hasDeletes
//     */
//    let checkUpdateCases = (ydoc: Doc, updates: Array<Data>, enc: Enc, hasDeletes: Bool) -> {
//        let cases: [Data] = []
//
//        // Case 1: Simple case, simply merge everything
//        cases.append(enc.mergeUpdates(updates))
//
//        // Case 2: Overlapping updates
//        cases.append(enc.mergeUpdates([
//            enc.mergeUpdates(updates.slice(2)),
//            enc.mergeUpdates(updates.slice(0, 2))
//        ]))
//
//        // Case 3: Overlapping updates
//        cases.append(enc.mergeUpdates([
//            enc.mergeUpdates(updates.slice(2)),
//            enc.mergeUpdates(updates.slice(1, 3)),
//            updates[0]
//        ]))
//
//        // Case 4: Separated updates (containing skips)
//        cases.append(enc.mergeUpdates([
//            enc.mergeUpdates([updates[0], updates[2]]),
//            enc.mergeUpdates([updates[1], updates[3]]),
//            enc.mergeUpdates(updates.slice(4))
//        ]))
//
//        // Case 5: overlapping with mAny duplicates
//        cases.append(enc.mergeUpdates(cases))
//
//        // let targetState = enc.encodeStateAsUpdate(ydoc)
//        // t.info("Target State: ")
//        // enc.logUpdate(targetState)
//
//        cases.forEach((mergedUpdates, i) -> {
//            // t.info("State Case $" + i + ":")
//            // enc.logUpdate(updates)
//            let merged = Doc({ gc: false })
//            enc.applyUpdate(merged, mergedUpdates)
//            XCTAssertEqualArrays(merged.getArray().toArray(), ydoc.getArray().toArray())
//            XCTAssertEqual(enc.encodeStateVector(merged), enc.encodeStateVectorFromUpdate(mergedUpdates))
//
//            if enc.updateEventName != "update" { // @todo should self also work on legacy updates?
//                for ( var j = 1; j < updates.length; j++) {
//                    let partMerged = enc.mergeUpdates(updates.slice(j))
//                    let partMeta = enc.parseUpdateMeta(partMerged)
//                    let targetSV = encodeStateVectorFromUpdateV2(mergeUpdatesV2(updates.slice(0, j)))
//                    let diffed = enc.diffUpdate(mergedUpdates, targetSV)
//                    let diffedMeta = enc.parseUpdateMeta(diffed)
//                    XCTAssertEqual(partMeta, diffedMeta)
//                    {
//                        // We can"d do the following
//                        //  - XCTAssertEqual(diffed, mergedDeletes)
//                        // because diffed contains the set of all deletes.
//                        // So we add all deletes from `diffed` to `partDeletes` and compare then
//                        let decoder = Lib0Decoder(diffed)
//                        let updateDecoder = UpdateDecoderV2(decoder)
//                        readClientsStructRefs(updateDecoder, Doc())
//                        let ds = DeleteSet.decode(updateDecoder)
//                        let updateEncoder = UpdateEncoderV2()
//                        updateEncoder.restEncoder.writeUInt(0) // 0 structs
//                        ds.encode(updateEncoder)
//                        let deletesUpdate = updateEncoder.data
//                        let mergedDeletes = mergeUpdatesV2([deletesUpdate, partMerged])
//                        if !hasDeletes || enc != encDoc {
//                            // deletes will almost definitely lead to different encoders because of the mergeStruct feature that is present in encDoc
//                            XCTAssertEqual(diffed, mergedDeletes)
//                        }
//                    }
//                }
//            }
//
//            let meta = enc.parseUpdateMeta(mergedUpdates)
//            meta.from.forEach((clock, client) -> XCTAssert(clock == 0))
//            meta.to.forEach((clock, client) -> {
//                let structs = merged.store.clients.get(client) as Item[]
//                let lastStruct = structs[structs.length - 1]
//                XCTAssert(lastStruct.id.clock + lastStruct.length == clock)
//            })
//        })
//    }
//
//    /**
//     * @param {t.TestCase} tc
//     */
//    export let testMergeUpdates1 = (tc: t.TestCase) -> {
//        encoders.forEach((enc, i) -> {
//            t.info(`Using encoder: ${enc.description}`)
//            let ydoc = Doc({ gc: false })
//            let updates: [Data] = []
//            ydoc.on(enc.updateEventName, (update: Data) -> { updates.append(update) })
//
//            let array = ydoc.getArray()
//            array.insert(0, [1])
//            array.insert(0, [2])
//            array.insert(0, [3])
//            array.insert(0, [4])
//
//            checkUpdateCases(ydoc, updates, enc, false)
//        })
//    }
//
//    /**
//     * @param {t.TestCase} tc
//     */
//    export let testMergeUpdates2 = (tc: t.TestCase) -> {
//        encoders.forEach((enc, i) -> {
//            t.info(`Using encoder: ${enc.description}`)
//            let ydoc = Doc({ gc: false })
//            let updates: [Data] = []
//            ydoc.on(enc.updateEventName, (update: Data) -> { updates.append(update) })
//
//            let array = ydoc.getArray()
//            array.insert(0, [1, 2])
//            array.delete(1, 1)
//            array.insert(0, [3, 4])
//            array.delete(1, 2)
//
//            checkUpdateCases(ydoc, updates, enc, true)
//        })
//    }
//
//    /**
//     * @param {t.TestCase} tc
//     */
//    export let testMergePendingUpdates = (tc: t.TestCase) -> {
//        let yDoc = Doc()
//        /**
//         * @type {Array<>}
//         */
//        let serverUpdates: [Data] = []
//        yDoc.on("update", (update: Data, origin: Any, c: Any) -> {
//            serverUpdates.splice(serverUpdates.length, 0, update)
//        })
//        let yText = yDoc.getText("textBlock")
//        yText.applyDelta([{ insert: "r" }])
//        yText.applyDelta([{ insert: "o" }])
//        yText.applyDelta([{ insert: "n" }])
//        yText.applyDelta([{ insert: "e" }])
//        yText.applyDelta([{ insert: "n" }])
//
//        let yDoc1 = Doc()
//        applyUpdate(yDoc1, serverUpdates[0])
//        let update1 = encodeStateAsUpdate(yDoc1)
//
//        let yDoc2 = Doc()
//        applyUpdate(yDoc2, update1)
//        applyUpdate(yDoc2, serverUpdates[1])
//        let update2 = encodeStateAsUpdate(yDoc2)
//
//        let yDoc3 = Doc()
//        applyUpdate(yDoc3, update2)
//        applyUpdate(yDoc3, serverUpdates[3])
//        let update3 = encodeStateAsUpdate(yDoc3)
//
//        let yDoc4 = Doc()
//        applyUpdate(yDoc4, update3)
//        applyUpdate(yDoc4, serverUpdates[2])
//        let update4 = encodeStateAsUpdate(yDoc4)
//
//        let yDoc5 = Doc()
//        applyUpdate(yDoc5, update4)
//        applyUpdate(yDoc5, serverUpdates[4])
//        // @ts-ignore
//        let update5 = encodeStateAsUpdate(yDoc5) // eslint-disable-line
//
//        let yText5 = yDoc5.getText("textBlock")
//        XCTAssertEqualStrings(yText5.toString(), "nenor")
//    }
//
}
