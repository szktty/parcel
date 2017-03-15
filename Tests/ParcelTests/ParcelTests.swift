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
        let exp = self.expectation(description: "example")
        var count = 0
        let parcel = Parcel<Area>.spawn {
            parcel in
            parcel.onReceive {
                message in
                switch message {
                case .rectangle(let width, let height):
                    print("Area of rectangle is \(width), \(height)")
                    count += 1
                case .circle(let r):
                    let circle = 3.14159 * r * r
                    count += 1
                    print("Area of circle is \(circle)")
                case .exit:
                    if count == 2 {
                        exp.fulfill()
                    }
                    print("Exit")
                    return .break
                }
                return .continue
            }
        }
        parcel ! .rectangle(6, 10)
        parcel ! .circle(23)
        parcel ! .exit
        self.waitForExpectations(timeout: 2)
    }
    
    func testRepeatSpawn() {
        measure {
            let n = 10000
            for _ in 0...n {
                let parcel = Parcel<Void>.spawn {
                    parcel in
                    parcel.onReceive { return .break }
                }
                parcel ! ()
            }
        }
    }
    
    func testTimeout() {
        let exp = self.expectation(description: "timeout test")
        let _ = Parcel<Void>.spawn {
            parcel in
            parcel.after(deadline: DispatchTime(uptimeNanoseconds: 1000)) {
                exp.fulfill()
            }
        }
        self.waitForExpectations(timeout: 2)
    }

    func testLink() {
        let exp = self.expectation(description: "link test")
        let parcel1 = Parcel<Void>.spawn {
            parcel in
            parcel.onReceive {
                throw NSError(domain: "Parcel", code: 0)
            }
        }
        let parcel2 = Parcel<Void>.spawn {
            parcel in
            parcel.onTerminate { signal in
                exp.fulfill()
            }
        }
        parcel1.addLink(parcel2)
        parcel1 ! ()
        self.waitForExpectations(timeout: 2)
    }
    
    func testMonitor() {
        let exp = expectation(description: "moniter test")
        let target = Parcel<Void>.spawn {
            parcel in
            parcel.onReceive {
                throw NSError(domain: "Parcel", code: 0)
            }
        }
        let monitor = Parcel<Void>.spawn {
            parcel in
            parcel.onTerminate { signal in
                switch signal {
                case .down:
                    exp.fulfill()
                default:
                    break
                }
            }
        }
        target.addMonitor(monitor)
        target ! ()
        waitForExpectations(timeout: 2)
    }
    
}
