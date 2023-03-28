import XCTest
import Promise


//final class Location: YBindingObject {
//    @YProperty var x: Double = 0
//    @YProperty var y: Double = 0
//    
//    let storage = YBindStorage()
//
//    init() {
//        self.storage.register(_x, for: "x")
//        self.storage.register(_y, for: "y")
//    }
//}
// 
//final class Person: YBindingObject {
//    @YProperty var name: String = ""
//    @YProperty var age: Int = 0
//    
//    let children = YBindingArray<String>()
//    let location = Location()
//    
//    let storage = YBindStorage()
//    
//    init() {
//        self.storage.register(_name, for: "name")
//        self.storage.register(_age, for: "age")
//        self.storage.register(children, for: "children")
//        self.storage.register(location, for: "location")
//    }
//}
//
//class Classroom: YBindingObject {
//    let members = YBindingObjectArray<Person>()
//    
//    let storage: YBindStorage
//
//    init(storage: YBindStorage) { self.storage = storage }
//}
//
//
//final class BindingTests: XCTestCase {
//    func testBinding() throws {
//        let test = try YTest<Any>(docs: 1)
//        let doc = test.docs[0]
//        
//        let classroom = try doc.makeBindingRoot(Classroom.init)
//        
//        
//    }
//}
