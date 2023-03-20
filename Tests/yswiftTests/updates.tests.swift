import XCTest
import Promise
@testable import yswift

final public class UpdateEnvironment {
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
    
    init(
        mergeUpdates: @escaping ([Data]) throws -> Data,
        encodeStateAsUpdate: @escaping (Doc, Data?) throws -> Data,
        applyUpdate: @escaping (Doc, Data, Any?) throws -> Void,
        logUpdate: @escaping (Data) -> Void,
        parseUpdateMeta: @escaping (Data) throws -> UpdateMeta,
        encodeStateVectorFromUpdate: @escaping (Data) throws -> Data,
        encodeStateVector_Doc: @escaping (Doc) throws -> Data,
        encodeStateVector_SV: @escaping ([Int : Int]) throws -> Data,
        updateEventName: Lib0Observable.EventName<(update: Data, origin: Any?, Transaction)>,
        description: String,
        diffUpdate: @escaping (Data, Data) throws -> Data
    ) {
        self.mergeUpdates = mergeUpdates
        self.encodeStateAsUpdate = encodeStateAsUpdate
        self.applyUpdate = applyUpdate
        self.logUpdate = logUpdate
        self.parseUpdateMeta = parseUpdateMeta
        self.encodeStateVectorFromUpdate = encodeStateVectorFromUpdate
        self.encodeStateVector_Doc = encodeStateVector_Doc
        self.encodeStateVector_SV = encodeStateVector_SV
        self.updateEventName = updateEventName
        self.description = description
        self.diffUpdate = diffUpdate
    }

    
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
    
    func testMergeUpdates1() throws {
        for env in UpdateEnvironment.encoders {
            print("== Using encoder: \(env.description) ==")
            let ydoc = Doc(opts: DocOpts(gc: false))
            var updates = [Data]()
            ydoc.on(env.updateEventName) { update, _, _ in updates.append(update) }

            let array = try ydoc.getArray()
            try array.insert(0, content: [1])
            try array.insert(0, content: [2])
            try array.insert(0, content: [3])
            try array.insert(0, content: [4])

            try checkUpdateCases(ydoc: ydoc, updates: updates, enc: env, hasDeletes: false)
        }
    }

    func testMergeUpdates2() throws {
        for env in UpdateEnvironment.encoders {
            print("== Using encoder: \(env.description) ==")
            let ydoc = Doc(opts: DocOpts(gc: false))
            var updates: [Data] = []
            ydoc.on(env.updateEventName) {
                update, _, _ in updates.append(update)
            }

            let array = try ydoc.getArray()
            try array.insert(0, content: [1, 2])
            try array.delete(1, length: 1)
            try array.insert(0, content: [3, 4])
            try array.delete(1, length: 2)

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
        let update1 = try encodeStateAsUpdate(doc: yDoc1)

        let yDoc2 = Doc()
        try applyUpdate(ydoc: yDoc2, update: update1)
        try applyUpdate(ydoc: yDoc2, update: serverUpdates[1])
        let update2 = try encodeStateAsUpdate(doc: yDoc2)

        let yDoc3 = Doc()
        try applyUpdate(ydoc: yDoc3, update: update2)
        try applyUpdate(ydoc: yDoc3, update: serverUpdates[3])
        let update3 = try encodeStateAsUpdate(doc: yDoc3)

        let yDoc4 = Doc()
        try applyUpdate(ydoc: yDoc4, update: update3)
        try applyUpdate(ydoc: yDoc4, update: serverUpdates[2])
        let update4 = try encodeStateAsUpdate(doc: yDoc4)

        let yDoc5 = Doc()
        try applyUpdate(ydoc: yDoc5, update: update4)
        try applyUpdate(ydoc: yDoc5, update: serverUpdates[4])
        _ = try encodeStateAsUpdate(doc: yDoc5)

        let yText5 = try yDoc5.getText("textBlock")
        XCTAssertEqual(yText5.toString(), "nenor")
    }
    
    private func checkUpdateCases(ydoc: Doc, updates: [Data], enc: UpdateEnvironment, hasDeletes: Bool) throws {
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
            try XCTAssertEqualJSON(merged.getArray().toArray(), ydoc.getArray().toArray())
            
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
                        let decoder = Lib0Decoder(data: diffed)
                        let updateDecoder = try UpdateDecoderV2(decoder)
                        _ = try readClientsStructRefs(decoder: updateDecoder, doc: Doc())
                        let ds = try DeleteSet.decode(decoder: updateDecoder)
                        let updateEncoder = UpdateEncoderV2()
                        updateEncoder.restEncoder.writeUInt(0) // 0 structs
                        try ds.encode(updateEncoder)
                        let deletesUpdate = updateEncoder.toData()
                        let mergedDeletes = try mergeUpdatesV2(updates: [deletesUpdate, partMerged])
                        if !hasDeletes || enc !== UpdateEnvironment.doc {
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
