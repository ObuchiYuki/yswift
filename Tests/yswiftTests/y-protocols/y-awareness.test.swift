import XCTest
import Promise
import yswift
import Combine

final class YAwarenessTests: XCTestCase {
    struct Cursor: Codable {
        let name: String
        var position: CGPoint
    }
    
    func testAwarenessSync() throws {
        let test = YAwarenessTest<Cursor>(count: 2)
        
        let awareness0 = test.awarenesses[0]
        let awareness1 = test.awarenesses[1]
        
        awareness0.localState = Cursor(name: "Alice", position: CGPoint(x: 10, y: 10))
                
        
        print(awareness1.states)
    }
}

final class YAwarenessTest<State: Codable> {
    let awarenesses: [YAwareness<State>]
    
    private var objectBag = [AnyCancellable]()
    
    init(count: Int) {
        var awarenesses = [YAwareness<State>]()
        let document = YDocument()
        
        for _ in 0..<count {
            let awareness = YAwareness<State>(document)
            awareness.updatePublisher
                .sink{ (update, origin) in
                    guard case .local = origin,
                          let update = awareness.encodeUpdate(of: update.changed.map{ $0 })
                    else { return }
                    
                    for a in awarenesses { a.applyUpdate(update, origin: .custom("test")) }
                }
                .store(in: &objectBag)
            awarenesses.append(awareness)
        }
        
        self.awarenesses = awarenesses
    }
}
