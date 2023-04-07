import XCTest
import Promise
@testable import yswift

class NameContainer: YObject {
    class Name: YObject {
        @Property var name: String = ""
        
        convenience init(_ name: String) { self.init(); self.name = name }
        required init() { super.init(); self.register(_name, for: "name") }
    }
    
    @WProperty var names: YArray<Name> = []
    
    convenience init(_ names: [Name]) { self.init(); self.names.append(contentsOf: names) }
    required init() { super.init(); self.register(_names, for: "names") }
}

final class YObjectTests2: XCTestCase {
    
    func testInfinity() throws {
        let container = NSMutableDictionary()
        container["inf"] = NSNumber(value: Float.infinity)
        print(container)
    }
    
    override func setUp() {
        NameContainer.registerAuto()
        NameContainer.Name.registerAuto()
    }
    
    func testReferenceObject() throws {
        class Layer: YObject {
            @Property var name: String = ""
            @Property var parent: YReference<Layer>?
            @WProperty var children: YArray<Layer> = []
            
            convenience init(_ name: String = "", _ children: [Layer] = []) {
                self.init()
                self.name = name
                self.children.append(contentsOf: children)
                children.forEach{ $0.parent = .reference(for: self) }
            }
            
            required init() {
                super.init()
                self.register(_name, for: "name")
                self.register(_parent, for: "parent")
                self.register(_children, for: "children")
            }
        }
        Layer.registerAuto()
        
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(Layer.self, 0), map1 = test.swiftyMap(Layer.self, 1)

        let inner0 = Layer("layer1_0")
        let root0 = Layer("root", [
            Layer("layer0_0"),
            Layer("container1", [ inner0 ]),
        ])
        
        XCTAssert(inner0.parent?.value.parent?.value === root0)
        
        map0["root"] = root0
        XCTAssert(inner0.parent?.value.parent?.value === root0)
        
        try test.sync()
        let root1 = try XCTUnwrap(map1["root"])
        
        
        let inner1 = root0.children[1].children[0]
        
        XCTAssert(inner1.parent?.value.parent?.value === root1)
    }
    
    func testArrayPublisherSync() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(NameContainer.self, 0), map1 = test.swiftyMap(NameContainer.self, 1)

        let container0 = NameContainer()
        map0["container"] = container0
        try test.sync()
        let container1 = try XCTUnwrap(map1["container"])
        
        var names = [String]()
        container1.$names.map{ $0.map{ $0.$name }.combineLatestHandleEmpty }.switchToLatest()
            .sink{ names = $0.map{ $0 } }.store(in: &objectBag)
        
        XCTAssertEqual(names, [])

        container0.names.append(.init("Alice"))
        try test.sync()
        XCTAssertEqual(names, ["Alice"])
        
        container0.names.append(.init("Bob"))
        try test.sync()
        XCTAssertEqual(names, ["Alice", "Bob"])
        
        container0.names[0].name = "Alisa"
        try test.sync()
        XCTAssertEqual(names, ["Alisa", "Bob"])
    }
    
    
    func testArrayPublisherLocal() throws {
        let test = try YTest<Any>(docs: 1)
        let map0 = test.swiftyMap(NameContainer.self, 0)

        let container0 = NameContainer()
        
        var names = [String]()
        container0.$names.map{ $0.map{ $0.$name }.combineLatestHandleEmpty }.switchToLatest()
            .sink{ names = $0.map{ $0 } }.store(in: &objectBag)
        
        map0["container"] = container0
        XCTAssertEqual(names, [])

        container0.names.append(.init("Alice"))
        XCTAssertEqual(names, ["Alice"])
        
        container0.names.append(.init("Bob"))
        XCTAssertEqual(names, ["Alice", "Bob"])
        
        container0.names[0].name = "Alisa"
        XCTAssertEqual(names, ["Alisa", "Bob"])
    }
    
    func testSmartCopy() throws {
        class Layer: YObject {
            @Property var name: String = ""
            @Property var parent: YReference<Layer>? = nil
            @WProperty var children: YArray<Layer> = []
            
            convenience init(_ name: String, _ children: [Layer] = []) {
                self.init()
                self.name = name
                self.children.assign(children)
                children.forEach{ $0.parent = .reference(for: self) }
            }
            
            required init() {
                super.init()
                self.register(_name, for: "name")
                self.register(_parent, for: "parent")
                self.register(_children, for: "children")
            }
        }
        Layer.registerAuto()
        
        let test = try YTest<Any>(docs: 2)
        let (map0, map1) = test.swiftyMap2(Layer.self)
        
        let root0 = Layer("root", [
            Layer("child0", [
                Layer("child1")
            ])
        ])
        let inner = root0.children[0].children[0]
        XCTAssert(inner.parent?.value.parent?.value === root0)
        
        map0["root"] = root0
        XCTAssert(map0["root"]?.children[0].children[0].parent?.value.parent?.value === map0["root"])
        
        try test.sync()
        let root1 = try XCTUnwrap(map1["root"])
        XCTAssert(root1.children[0].children[0].parent?.value.parent?.value === root1)
        
        let root0Copy = root0.smartCopy()
        
        XCTAssertEqual(root0Copy.children[0].children[0].parent?.value.parent?.value.objectID, root0Copy.objectID)

        map0["rootcopy"] = root0Copy
        try test.sync()

        let root1Copy = try XCTUnwrap(map1["rootcopy"])

        XCTAssertEqual(root1Copy.children[0].children[0].parent?.value.parent?.value.objectID, root1Copy.objectID)
    }
}
