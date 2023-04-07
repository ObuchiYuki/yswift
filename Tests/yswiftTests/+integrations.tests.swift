import XCTest
import Promise
import Combine
@testable import yswift

final class IntegrationsTests: XCTestCase {
    func testEnum() throws {
        enum Sex: Int, YRawRepresentable { case man = 0, weman = 1 }
        
        class Person: YObject {
            @Property var name: String = ""
            @Property var sex: Sex = .man
            
            convenience init(name: String, sex: Sex) {
                self.init()
                self.name = name
                self.sex = sex
            }
            
            required init() {
                super.init()
                self.register(_sex, for: "sex")
                self.register(_name, for: "name")
            }
        }
        Person.registerAuto()
        
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(Person.self, 0), map1 = test.swiftyMap(Person.self, 1)
        
        let alice0 = Person(name: "Alice", sex: .weman)
        map0["alice"] = alice0
        
        try test.sync()
        
        let alice1 = try XCTUnwrap(map1["alice"])
        
        XCTAssertEqual(alice1.name, "Alice")
        XCTAssertEqual(alice1.sex, .weman)
    }
    
    func testStruct() throws {
        struct Point: Hashable, Codable, YElement {
            var x: Float
            var y: Float
        }
                
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(Point.self, 0), map1 = test.swiftyMap(Point.self, 1)

        map0["point"] = Point(x: 12, y: 10)
        
        try test.sync()
        
        let point1 = try XCTUnwrap(map1["point"])
        
        XCTAssertEqual(point1, Point(x: 12, y: 10))
    }
    
    func testStructExisting() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(CGPoint.self, 0), map1 = test.swiftyMap(CGPoint.self, 1)

        print(CGPoint(x: 12, y: 10).persistenceObject())
        map0["point"] = CGPoint(x: 12, y: 10)
        
        print(map0.opaque)
        
        try test.sync()

        print(map1.opaque)
        
        let point1 = try XCTUnwrap(map1["point"])

        XCTAssertEqual(point1, CGPoint(x: 12, y: 10))
    }
}

extension CGPoint: YElement {}
