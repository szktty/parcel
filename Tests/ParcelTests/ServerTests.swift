import XCTest
@testable import Parcel

final class MyBankContext: ServerContext {
    
    public typealias Config = Void
    public typealias Client = Void
    public typealias Message = String
    public typealias Response = Void
    public typealias Error = Void
    
    enum Request {
        case add(Int)
        case remove(Int)
        case stop
    }
    
    func initialize(config: Config?) -> ServerInit<MyBankContext> {
        return .ignore
    }
    
    func onSendSync(client: Client?,
                    request: Request,
                    block: (Response) -> Void) -> ServerSendSync<MyBankContext> {
        block(())
        switch request {
        case .stop:
            return .terminate(error: ())
        default:
            return .sync(timeout: nil)
        }
    }
    
    func onSendAsync(client: Client, request: Request) -> ServerSendAsync<MyBankContext> {
        return .ignore(timeout: nil)
    }
    
    func onTerminate(error: Error) {
        
    }
    
}

class MyBank {
    
    var server: Server<MyBankContext>
    var context: MyBankContext
    
    init() {
        context = MyBankContext()
        server = Server<MyBankContext>(context: context)
    }
    
    func run() {
        server.run()
    }
    
    func stop() {
        server.sendSync(request: .stop)
    }
    
    func deposit(amount: Int) {
        server.sendSync(request: .add(amount))
    }
    
    func withdraw(amount: Int) {
        server.sendSync(request: .remove(amount))
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
        let bank = MyBank()
        bank.run()
        bank.stop()
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
