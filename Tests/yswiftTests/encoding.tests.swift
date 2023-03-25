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
        
        try applyUpdate(ydoc: ydoc2, update: encodeStateAsUpdate(doc: ydoc1))
        try applyUpdate(ydoc: ydoc1, update: encodeStateAsUpdate(doc: ydoc2))

        // now sync a third doc with same name as doc1 and then create PermanentUserData
        let ydoc3 = Doc()
        try applyUpdate(ydoc: ydoc3, update: encodeStateAsUpdate(doc: ydoc1))
        let pd3 = try PermanentUserData(doc: ydoc3, storeType: nil)
        try pd3.setUserMapping(doc: ydoc3, clientid: Int(ydoc3.clientID), userDescription: "user a")
    }
    
    
    func testDiffStateVectorOfUpdateIsEmpty() throws {
        let ydoc = Doc()
        var sv: Data? = nil
        try ydoc.getText().insert(0, text: "a")
        ydoc.on(Doc.On.update) { update, _, _ in
            sv = try encodeStateVectorFromUpdate(update: update)
        }
        
        try ydoc.getText().insert(0, text: "a")
        try XCTAssertEqual(XCTUnwrap(sv).map{ $0 }, [0])
    }

    func testDiffStateVectorOfUpdateIgnoresSkips() throws {
        let ydoc = Doc()
        var updates: [Data] = []
        ydoc.on(Doc.On.update) { update, _, _ in
            updates.append(update)
        }
        try ydoc.getText().insert(0, text: "a")
        try ydoc.getText().insert(0, text: "b")
        try ydoc.getText().insert(0, text: "c")
                
        let update13 = try mergeUpdates(updates: [updates[0], updates[2]])
                
        let sv = try encodeStateVectorFromUpdate(update: update13)
        let state = try decodeStateVector(decodedState: sv)
        XCTAssertEqual(state[ydoc.clientID], 1)
        XCTAssertEqual(state.count, 1)
    }
    
}

