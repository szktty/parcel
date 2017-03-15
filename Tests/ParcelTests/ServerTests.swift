import XCTest
@testable import Parcel

final class MyBank: ServerBehavior {
    
    public typealias Config = Void
    public typealias Request = Void
    public typealias State = Void
    public typealias Message = String
    public typealias Reply = Void
    
    public static func run(config: Config) -> Server<MyBank> {
        let server = Server<MyBank>(behavior: MyBank())
        server.run(config: config)
        return server
    }
    
    func initialize(config: Config) -> ServerInitResult<MyBank> {
        return .ignore
    }
    
    func onSendSync(state: State, request: Request, from: Parcel<Message>) -> ServerSendSyncResult<MyBank> {
        return .noreply(state: state, timeout: nil)
    }
    
    func onSendAsync(state: State, request: Request) -> ServerSendAsyncResult<MyBank> {
        return .noreply(state: state, timeout: nil)
    }
    
    func onReceive(state: State, message: Message) -> ServerReceiveResult<MyBank> {
        return .noreply(state: state, timeout: nil)
    }
    
    func terminate(state: State, error: Error?) {
        
    }
    
}

class ServerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
