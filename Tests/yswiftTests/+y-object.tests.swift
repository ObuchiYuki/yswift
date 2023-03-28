import XCTest
import Promise
@testable import yswift

final class ObjectTests: XCTestCase {
    final class Person: YObject {
        @Property public var name: String = ""
        @Property public var age: Int = 0
        
        required init() {
            super.init()
            self.register(_name, for: "name")
            self.register(_age, for: "age")
        }
        
        convenience init(name: String, age: Int) {
            self.init()
            self.name = name
            self.age = age
        }
    }

    final class PersonOptional: YObject {
        @Property public var name: String?
        @Property public var age: Int?
        
        required init() {
            super.init()
            self.register(_name, for: "name")
            self.register(_age, for: "age")
        }
    }

    final class PersonPair: YObject {
        @Property var person0: Person?
        @Property var person1: Person?
        
        required init() {
            super.init()
            self.register(_person0, for: "p0")
            self.register(_person1, for: "p1")
        }
    }

    class Base: YObject {
        @Property var base: String = "base"
        
        required init() {
            super.init()
            self.register(_base, for: "base")
        }
    }

    final class Sub1: Base {
        @Property var sub1: String = "sub1"
        
        required init() {
            super.init()
            self.register(_sub1, for: "sub1")
        }
    }

    final class Sub2: Base {
        @Property var sub2: String = "sub2"
        
        required init() {
            super.init()
            self.register(_sub2, for: "sub2")
        }
    }

    final class BaseContainer: YObject {
        @Property var base: Base?
        
        required init() {
            super.init()
            self.register(_base, for: "base")
        }
    }
    
    override func setUp() async throws {
        Person.register(0)
        PersonPair.register(1)
        PersonOptional.register(2)
        Base.register(3)
        Sub1.register(4)
        Sub2.register(5)
        BaseContainer.register(6)
    }
    override func tearDown() async throws {
        Person.unregister()
        PersonPair.unregister()
        PersonOptional.unregister()
        Base.unregister()
        Sub1.unregister()
        Sub2.unregister()
    }
    
    func testInheritedObjectSync() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(BaseContainer.self, 0), map1 = test.swiftyMap(BaseContainer.self, 1)
        
        let container0 = BaseContainer()
        map0["container"] = container0
        
        try test.connector.flushAllMessages()
        
        let container1 = try XCTUnwrap(map1["container"])
        
        XCTAssertNil(container0.base)
        XCTAssertNil(container1.base)
        
        container0.base = Sub1()
        try test.connector.flushAllMessages()
        XCTAssert(container1.base is Sub1)
        
        container0.base = Sub2()
        try test.connector.flushAllMessages()
        XCTAssert(container1.base is Sub2)
        
    }
    
    func testInheritedObjectLocal() throws {
        let test = try YTest<Any>(docs: 1)
        let map0 = test.swiftyMap(BaseContainer.self, 0)
        
        let container = BaseContainer()
        map0["container"] = container
        
        let base = Base()
        let sub1 = Sub1()
        let sub2 = Sub2()
        
        XCTAssertEqual(container.base, nil)
        
        container.base = base
        XCTAssert(container.base === base)
        
        container.base = sub1
        XCTAssert(container.base === sub1)
        
        container.base = sub2
        XCTAssert(container.base === sub2)
    }
    
    func testNestedObjectPropertyLocal() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(PersonPair.self, 0)
        
        let pair = PersonPair()
        let alice0 = Person(name: "Alice", age: 16)
        let bob0 = Person(name: "Bob", age: 24)
        
        map0["pair"] = pair
        
        XCTAssertNil(pair.person0)
        XCTAssertNil(pair.person1)
        
        pair.person0 = alice0
        
        XCTAssertEqual(try XCTUnwrap(pair.person0).name, "Alice")
        XCTAssertEqual(try XCTUnwrap(pair.person0).age, 16)
        
        pair.person1 = bob0
        
        XCTAssertEqual(try XCTUnwrap(pair.person1).name, "Bob")
        XCTAssertEqual(try XCTUnwrap(pair.person1).age, 24)
    }
    
    func testNestedObjectPropertyPublisherLocal() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(PersonPair.self, 0)
        
        let pair = PersonPair()
        map0["pair"] = pair
        
        var receivedNames = [String]()
        pair.$person0.compactMap{ $0?.$name }.switchToLatest()
            .sink{ receivedNames.append($0) }.store(in: &objectBag)
        
        let alice0 = Person(name: "Alice", age: 16)
        let bob0 = Person(name: "Bob", age: 24)

        XCTAssertEqual(receivedNames, [])
        
        pair.person0 = alice0
        
        XCTAssertEqual(receivedNames, ["Alice"])
        
        pair.person0 = bob0
        
        XCTAssertEqual(receivedNames, ["Alice", "Bob"])
    }
    
    func testOptionalPropertyLocal() throws {
        let person = PersonOptional()
        
        XCTAssertEqual(person.name, nil)
        XCTAssertEqual(person.age, nil)
        
        person.name = "Alice"
        
        XCTAssertEqual(person.name, "Alice")
        
        person.age = 16
        
        XCTAssertEqual(person.age, 16)
    }
    
    func testOptionalPropertySync() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(PersonOptional.self, 0), map1 = test.swiftyMap(PersonOptional.self, 1)
        
        let person0 = PersonOptional()
        map0["person"] = person0
        
        XCTAssertNil(person0.name)
        XCTAssertNil(person0.age)
        
        person0.name = "Alice"
        
        XCTAssertEqual(person0.name, "Alice")
        
        let person1 = try XCTUnwrap(map1["person"])
        
        XCTAssertEqual(person1.name, "Alice")
        XCTAssertNil(person1.age)
    }
    
    func testObjectPropertySync() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(Person.self, 0), map1 = test.swiftyMap(Person.self, 1)
        
        let alice0 = Person(name: "Alice", age: 16)
        XCTAssertEqual(alice0.name, "Alice")
        XCTAssertEqual(alice0.age, 16)
        
        map0["person"] = alice0
        XCTAssertEqual(alice0.name, "Alice")
        XCTAssertEqual(alice0.age, 16)
        
        try test.connector.flushAllMessages()
        
        let alice1 = try XCTUnwrap(map1["person"])
        XCTAssertEqual(alice1.name, "Alice")
        XCTAssertEqual(alice1.age, 16)
        
        alice0.name = "Bob"
        alice0.age = 24
        
        try test.connector.flushAllMessages()
        
        XCTAssertEqual(alice1.name, "Bob")
        XCTAssertEqual(alice1.age, 24)
    }
    
    func testObjectPropertySyncPublisherLocal() throws {
        let test = try YTest<Any>(docs: 1)
        let map0 = test.swiftyMap(Person.self, 0)
        
        let person = Person(name: "Alice", age: 16)
        
        var receivedNames = [String]()
        var receivedAges = [Int]()
        
        person.$name.sink{ receivedNames.append($0) }.store(in: &objectBag)
        person.$age.sink{ receivedAges.append($0) }.store(in: &objectBag)
        
        // published initial value
        XCTAssertEqual(receivedNames, ["Alice"])
        XCTAssertEqual(receivedAges, [16])
        
        map0["person"] = person
        
        // set don't make publish
        XCTAssertEqual(receivedNames, ["Alice"])
        XCTAssertEqual(receivedAges, [16])
        
        // set make publish for specific property
        person.name = "Bob"
        XCTAssertEqual(receivedNames, ["Alice", "Bob"])
        XCTAssertEqual(receivedAges, [16])
        
        // set make publish for specific property
        person.age = 24
        XCTAssertEqual(receivedNames, ["Alice", "Bob"])
        XCTAssertEqual(receivedAges, [16, 24])
    }
    
    func testObjectPropertySyncPublisher() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(Person.self, 0)
        let map1 = test.swiftyMap(Person.self, 1)

        let person0 = Person(name: "Alice", age: 16)
        
        var received0Names = [String]()
        var received0Ages = [Int]()
        
        person0.$name.sink{ received0Names.append($0) }.store(in: &objectBag)
        person0.$age.sink{ received0Ages.append($0) }.store(in: &objectBag)

        //
        XCTAssertEqual(received0Names, ["Alice"])
        XCTAssertEqual(received0Ages, [16])
        
        map0["person"] = person0
        XCTAssertEqual(received0Names, ["Alice"])
        XCTAssertEqual(received0Ages, [16])
        
        XCTAssertNil(map1["person"])
        
        try test.connector.flushAllMessages()
        
        let person1 = try XCTUnwrap(map1["person"])
        
        var received1Names = [String]()
        var received1Ages = [Int]()
        
        person1.$name.sink{ received1Names.append($0) }.store(in: &objectBag)
        person1.$age.sink{ received1Ages.append($0) }.store(in: &objectBag)
        
        XCTAssertEqual(received0Names, ["Alice"])
        XCTAssertEqual(received0Ages, [16])
        XCTAssertEqual(received1Names, ["Alice"])
        XCTAssertEqual(received1Ages, [16])
        
        person0.name = "Bob"
        try test.connector.flushAllMessages()
        
        XCTAssertEqual(received0Names, ["Alice", "Bob"])
        XCTAssertEqual(received0Ages, [16])
        XCTAssertEqual(received1Names, ["Alice", "Bob"])
        XCTAssertEqual(received1Ages, [16])
        
        person0.age = 24
        try test.connector.flushAllMessages()
        
        XCTAssertEqual(received0Names, ["Alice", "Bob"])
        XCTAssertEqual(received0Ages, [16, 24])
        XCTAssertEqual(received1Names, ["Alice", "Bob"])
        XCTAssertEqual(received1Ages, [16, 24])
    }
    
    
}

