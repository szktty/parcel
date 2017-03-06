import XCTest
@testable import Parcel

enum Area {
    case rectangle(Int, Int)
    case circle(Float)
    case exit
}

class ParcelTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        let actor = Actor<Area>.spawn {
            actor in
            actor.receive {
                message in
                switch message {
                case .rectangle(let width, let height):
                    print("Area of rectangle is \(width), \(height)")
                case .circle(let r):
                    let circle = 3.14159 * r * r
                    print("Area of circle is \(circle)")
                case .exit:
                    print("Exit")
                    return .break
                }
                return .continue
            }
        }
        actor ! .rectangle(6, 10)
        actor ! .circle(23)
        actor ! .exit
    }
    
    func _testRepeatSpawn() {
        let n = 100000
        for _ in 0...n {
            let actor = Actor<Void>.spawn {
                actor in
                actor.receive { return .break }
            }
            actor ! ()
        }
    }
    
    func _testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
            /*
            self.expectation(description: "percel test")
            self.waitForExpectations(timeout: 30)
 */
        }
    }

}
