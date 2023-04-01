import XCTest
import yswift

class Point: YObject {
    @Property var x: Double = 0
    @Property var y: Double = 0
    
//    convenience init(x: Double = 0, y: Double = 0) {
//        self.init()
//        self.x = x
//        self.y = y
//    }
    
    required init() {
        super.init()
        self.register(_x, for: "x")
        self.register(_y, for: "y")
    }
}

class Layer: YObject {
    @Property var position: Point = Point()
    @Property var name: String = "Untitled Layer"
    
//    convenience init(name: String) {
//        self.init()
//        self.name = name
//    }
    
    required init() {
        super.init()
        self.register(_name, for: "name")
        self.register(_position, for: "pos")
    }
}

class Container: Layer {
    let children: YArray<Layer> = []
    
    required init() {
        super.init()
        self.register(children, for: "children")
    }
}

final class PublicAPITests: XCTestCase {
    override func setUp() {
        Point.registerAuto()
        Layer.registerAuto()
        Container.registerAuto()
    }
    
    func testDocAPI() throws {
        let test = try YTest<Any>(docs: 2)
        
        let root0 = doc0.getObject(Container.self, "root")
        root0.name = "Root"
        
        try test.sync()
  
        let root1 = doc1.getObject(Container.self, "root")
        print(root1.name)
        
    }
}
