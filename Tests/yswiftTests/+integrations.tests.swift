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
}
