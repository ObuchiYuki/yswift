import XCTest
@testable import yswift

final class yswiftTests: XCTestCase {
    func testExample() throws {
        let doc1 = Doc(opts: DocOpts(cliendID: 100))
        let doc2 = Doc(opts: DocOpts(cliendID: 101))
        
        doc1.on(Doc.Event.update) { update, _, _ in
            print(update.map{ $0 })
            try! applyUpdate(ydoc: doc2, update: update, transactionOrigin: nil)
        }
        
        let root1 = try doc1.getMap(name: "root")
        try root1.set("A", value: "B")
        
        let root2 = try doc2.getMap(name: "root")
        print(root2.get("A")) 
    }
}
