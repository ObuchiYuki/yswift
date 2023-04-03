import XCTest
import Promise
@testable import yswift

final class YObjectTests2: XCTestCase {
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
    
    func testSmartCopy() throws {
        class OutSocket: YObject {
            @Property var connection: YReference<InSocket>?
            
            required init() {
                super.init()
                self.register(_connection, for: "connection")
            }
        }
        OutSocket.registerAuto()
        
        class InSocket: YObject {
            @Property var connection: YReference<OutSocket>?
            
            required init() {
                super.init()
                self.register(_connection, for: "connection")
            }
        }
        InSocket.registerAuto()
        
        class Node: YObject {
            @Property var name: String = ""
            
            convenience init(name: String) {
                self.init()
                self.name = name
            }
            
            required init() {
                super.init()
                self.register(_name, for: "name")
            }
        }
        Node.registerAuto()
        
        class AddNode: Node {
            @Property var input0: InSocket?
            @Property var input1: InSocket?
            @Property var output: OutSocket?
            
            required init() {
                super.init()
                self.register(_input0, for: "i0")
                self.register(_input1, for: "i1")
                self.register(_output, for: "o1")
            }
        }
        
        class Graph: YObject {
            @WProperty var nodes: YArray<Node> = []
            
            required init() {
                super.init()
                self.register(_nodes, for: "nodes")
            }
        }
        Graph.registerAuto()
        
        let graph = Graph()
        
        
    }
}
