import XCTest
@testable import Parcel

final class MyBank: ServerContext {
    
    public typealias Config = Void
    public typealias Message = String
    public typealias Request = Void
    public typealias Response = Void
    public typealias Error = Void
    
    public static func run(config: Config) -> Server<MyBank> {
        let server = Server<MyBank>(context: MyBank())
        server.run(config: config)
        return server
    }
    
    func initialize(config: Config) -> ServerInitResult<MyBank> {
        return .ignore
    }
    
    func onSendSync(client: Parcel<Response>,  request: Request) -> ServerSendSyncResult<MyBank> {
        return .ignore(timeout: nil)
    }
    
    func onSendAsync(client: Parcel<Response>, request: Request) -> ServerSendAsyncResult<MyBank> {
        return .ignore(timeout: nil)
    }
    
    func terminate(client: Parcel<Response>, error: Error?) {
        
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
