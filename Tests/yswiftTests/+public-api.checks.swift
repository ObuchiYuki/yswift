import XCTest
import yswift

final class PublicAPITests: XCTestCase {
    func testDocAPI() {
        let document = YDocument()
        
        let array = document.getArray(String.self)
        array.append("Hello")
        
    }
}
