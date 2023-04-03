import XCTest
import yswift

class Layer: YObject {
    @Property var name: String = "Untitled Layer"
    @Property var parent: YReference<Layer>?

    @WProperty var children: YArray<Layer> = []
    
    func addSublayer(_ layer: Layer) {
        self.children.append(layer)
        layer.parent = .reference(for: self)
    }
    
    convenience init(name: String) {
        self.init()
        self.name = name
    }
    
    required init() {
        super.init()
        self.register(_name, for: "name")
        self.register(_parent, for: "parent")
        self.register(_children, for: "children")
    }
}

final class PublicAPITests: XCTestCase {
    override func setUp() {
        Layer.registerAuto()
    }
    
    func testDocAPI() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(Layer.self, 0), map1 = test.swiftyMap(Layer.self, 1)
        
        let root0 = Layer(name: "Root")
        root0.addSublayer(Layer(name: "layer[0]"))
        map0["root"] = root0
        
        try test.sync()
        
        let root1 = try XCTUnwrap(map1["root"])
        
        XCTAssert(root1.children[0].parent?.value === root1)
    }
}
