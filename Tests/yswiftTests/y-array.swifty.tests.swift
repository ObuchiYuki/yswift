import XCTest
import Promise
import Combine
@testable import yswift

final class YArraySwiftyTests: XCTestCase {
    
    private var objectBag = Set<AnyCancellable>()
        
    func testArrayPrimitiveType() throws {
        let test = try YTest<Any>(docs: 1)
        let array = test.swiftyArray(Int.self, 0)
                
        try array.append(1)
        try array.append(2)
        try array.append(3)
                
        XCTAssertEqual(array.count, 3)
        XCTAssertEqual(array[0], 1)
        XCTAssertEqual(array[1], 2)
        XCTAssertEqual(array[2], 3)
        
        XCTAssertEqual(array[1..<2], [2])
        XCTAssertEqual(array[1...2], [2, 3])
        XCTAssertEqual(array[1...], [2, 3])
        XCTAssertEqual(array[...1], [1, 2])
        XCTAssertEqual(array[..<1], [1])
    }
    
    func testArrayConcreteType() throws {
        let test = try YTest<Any>(docs: 1)
        let array = test.swiftyArray(YArray<Int>.self, 0)

        try array.append(YArray([ 1 ]))
        try array.append(YArray([ 1, 2 ]))
        try array.append(YArray([ 1, 2, 3 ]))

        XCTAssertEqual(array.count, 3)

        XCTAssertEqual(array[0].count, 1)
        XCTAssertEqual(array[1].count, 2)
        XCTAssertEqual(array[2].count, 3)
    }
    
    
    func testArrayCodableType() throws {
        struct Point: Codable, Equatable, YElement { var x: Double, y: Double }

        let test = try YTest<Any>(docs: 1)
        let array = test.swiftyArray(Point.self, 0)
        
        try array.append(Point(x: 1, y: 11))
        try array.append(Point(x: 2, y: 22))
        try array.append(Point(x: 3, y: 33))
        
        XCTAssertEqual(array[0], Point(x: 1, y: 11))
        XCTAssertEqual(array[1], Point(x: 2, y: 22))
        XCTAssertEqual(array[2], Point(x: 3, y: 33))
    }
    
    func testArrayNestedType() throws {
        let test = try YTest<Any>(docs: 1)
        let array = test.swiftyArray(YArray<YArray<String>>.self, 0)
        
        try array.append(YArray([ YArray([ "Hello", "World" ]) ]))
        
        XCTAssertEqual(array[0][0].toArray(), [ "Hello", "World" ])
    }
    
    func testArrayPublisher() throws {
        let test = try YTest<Any>(docs: 1)
        let array = test.swiftyArray(Int.self, 0)
        
        var deltas = [YEventDelta]()
        array.publisher
            .sink{ deltas.append(contentsOf: try! $0.delta()) }
            .store(in: &objectBag)
        
        try array.append(12876)
        
        XCTAssertEqual(deltas, [ YEventDelta(insert: [12876]) ])
    }
    
    func testArrayNoneExclusiveAccess() throws {
        let test = try YTest<Any>(docs: 1)
        let array = test.swiftyArray(Int.self, 0)
        
        array.publisher
            .sink{_ in
                if array.count < 10 { try! array.append(array.count) }
            }
            .store(in: &objectBag)
        
        try array.append(0)
        
        XCTAssertEqual(array.toArray(), (0..<10).map{ $0 })
    }
    
    func testDocumentGetArray() throws {
        let test = try YTest<Any>(docs: 1)
        let doc = test.docs[0]
        
        let root = try doc.getMap(YArray<Int>.self)
        
        root["alice"] = [1, 2, 3]
        root["bob"] = [4, 5, 6]
        
        XCTAssertEqualJSON(root.toJSON(), [
            "alice": [1, 2, 3],
            "bob": [4, 5, 6],
        ])
    }
}

