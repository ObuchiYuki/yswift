import XCTest
import Promise
@testable import yswift

final class Person: YObject {
    public var name: String? {
        get { self.getValue(for: "name") as? String }
        set { try! self.setValue(newValue, for: "name") }
    }
    
    required init() {}
    convenience init(name: String) {
        self.init()
        self.name = name
    }
}

final class BindingTests: XCTestCase {
    func testBinding() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(Person.self, 0)
        let map1 = test.swiftyMap(Person.self, 1)
        
        Person.register(7)
        
        map0["alice"] = Person(name: "Alice")
        
        try test.connector.flushAllMessages()
        
        print(map1["alice"]?.name)
    }
}
