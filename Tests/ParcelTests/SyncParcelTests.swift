import XCTest
@testable import Parcel

class SyncParcelTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testComplete() {
        let exp = expectation(description: "immediate complete")
        let parcel: SyncParcel<String, Int> = SyncParcel.spawn { p in
            p.onReceive { message, complete in
                if let int = Int(message) {
                    complete?(.success(int))
                }
                return .continue
            }
        }
        let future = parcel !! "123"
        future.onComplete { result in
            XCTAssert(result.value == 123)
            exp.fulfill()
        }
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
