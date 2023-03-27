import XCTest
import Promise
@testable import yswift

final class EncodingTests: XCTestCase {
    
    func testStructReferences() {
        // Swift (intentionally) has no functions equality check.
    }

    func testPermanentUserData() async throws {
        let ydoc1 = Doc()
        let ydoc2 = Doc()
        let pd1 = try PermanentUserData(doc: ydoc1, storeType: nil)
        let pd2 = try PermanentUserData(doc: ydoc2, storeType: nil)
        try pd1.setUserMapping(doc: ydoc1, clientid: Int(ydoc1.clientID), userDescription: "user a")
        try pd2.setUserMapping(doc: ydoc2, clientid: Int(ydoc2.clientID), userDescription: "user b")
        try ydoc1.getText().insert(0, text: "xhi")
        try ydoc1.getText().delete(0, length: 1)
        try ydoc2.getText().insert(0, text: "hxxi")
        try ydoc2.getText().delete(1, length: 2)
        
        await Promise.wait(for: 1).value()
        
        try ydoc2.applyUpdate(ydoc1.encodeStateAsUpdate())
        try ydoc1.applyUpdate(ydoc2.encodeStateAsUpdate())

        // now sync a third doc with same name as doc1 and then create PermanentUserData
        let ydoc3 = Doc()
        try ydoc3.applyUpdate(ydoc1.encodeStateAsUpdate())
        let pd3 = try PermanentUserData(doc: ydoc3, storeType: nil)
        try pd3.setUserMapping(doc: ydoc3, clientid: Int(ydoc3.clientID), userDescription: "user a")
    }
    
    
    func testDiffStateVectorOfUpdateIsEmpty() throws {
        let ydoc = Doc()
        var sv: Data? = nil
        try ydoc.getText().insert(0, text: "a")
        ydoc.on(Doc.On.update) { update, _, _ in
            sv = try update.encodeStateVectorFromUpdate()
        }
        
        try ydoc.getText().insert(0, text: "a")
        try XCTAssertEqual(XCTUnwrap(sv).map{ $0 }, [0])
    }

    func testDiffStateVectorOfUpdateIgnoresSkips() throws {
        let ydoc = Doc()
        var updates: [YUpdate] = []
        ydoc.on(Doc.On.update) { update, _, _ in
            updates.append(update)
        }
        try ydoc.getText().insert(0, text: "a")
        try ydoc.getText().insert(0, text: "b")
        try ydoc.getText().insert(0, text: "c")
                
        let update13 = try YUpdate.merged([updates[0], updates[2]])
                
        let sv = try update13.encodeStateVectorFromUpdate()
        let state = try YDeleteSetDecoderV1(sv).readStateVector()
        XCTAssertEqual(state[ydoc.clientID], 1)
        XCTAssertEqual(state.count, 1)
    }
    
}

