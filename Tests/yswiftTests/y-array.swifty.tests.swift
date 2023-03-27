import XCTest
import Promise
@testable import yswift

final class YArraySwiftyTests: XCTestCase {
        
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
        struct Point: Codable, Equatable, YCodable { var x: Double, y: Double }

        let test = try YTest<Any>(docs: 1)
        let array = test.swiftyArray(Point.self, 0)
        
        try array.append(Point(x: 1, y: 11))
        try array.append(Point(x: 2, y: 22))
        try array.append(Point(x: 3, y: 33))
        
        try XCTAssertEqual(array[0], Point(x: 1, y: 11))
        try XCTAssertEqual(array[1], Point(x: 2, y: 22))
        try XCTAssertEqual(array[2], Point(x: 3, y: 33))
    }
    
    func testArrayNestedType() throws {
        let test = try YTest<Any>(docs: 1)
        let array = test.swiftyArray(YArray<YArray<String>>.self, 0)
        
        try array.append(YArray([ YArray([ "Hello", "World" ]) ]))
        
        XCTAssertEqual(array[0][0].toArray(), [ "Hello", "World" ])
    }
}
