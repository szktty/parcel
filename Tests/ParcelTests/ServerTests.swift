import XCTest
@testable import Parcel
import Result

final class MyBankContext: ServerContext {
    
    public typealias Config = Void
    public typealias Client = Void
    public typealias Message = String
    public typealias Response = Int
    
    enum Request {
        case new(who: String)
        case add(who: String, amount: Int)
        case remove(who: String, amount: Int)
        case stop
    }
    
    var clients: [String: Int] = [:]
    var isTerminated: Bool = false
    
    func initialize(server: Server<MyBankContext>,
                    config: Config?) -> ServerInit<MyBankContext> {
        return .ignore
    }
    
    func onSync(server: Server<MyBankContext>,
                client: Client?,
                request: Request,
                receiver: ServerResponseReceiver<MyBankContext>) {
        switch request {
        case .new(who: let who):
            clients[who] = 0
            receiver.return(response: 0)
            
        case .add(who: let who, amount: let amount):
            if let balance = clients[who] {
                clients[who] = balance + amount
            }
            receiver.return(response: clients[who])
            
        case .remove(who: let who, amount: let amount):
            if let balance = clients[who] {
                clients[who] = balance - amount
            }
            receiver.return(response: clients[who])
            
        case .stop:
            receiver.terminate(error: ServerError.normal)
        }
    }
    
    func onAsync(server: Server<MyBankContext>,
                 client: Client?,
                 request: Request,
                 receiver: ServerResponseReceiver<MyBankContext>) {
        // ignore
    }
    
    func onTerminate(server: Server<MyBankContext>, error: Error) {
        isTerminated = true
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
        let _ = server.run()
    }
    
    func stop() {
        let _ = server.sync(request: .stop)
    }
    
    func newAccount(who: String) -> Int? {
        return server.sync(request: .new(who: who)).value!
    }
    
    func deposit(who: String, amount: Int) -> Int? {
        return server.sync(request: .add(who: who, amount: amount)).value!
    }
    
    func withdraw(who: String, amount: Int) -> Int? {
        return server.sync(request: .remove(who: who, amount: amount)).value!
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
        let joe = "joe"
        XCTAssert(bank.newAccount(who: joe) == 0)
        XCTAssert(bank.deposit(who: joe, amount: 10) == 10)
        XCTAssert(bank.withdraw(who: joe, amount: 3) == 7)
        XCTAssert(bank.deposit(who: "john", amount: 10) == nil)
        
        XCTAssert(!bank.context.isTerminated)
        bank.stop()
        XCTAssert(bank.context.isTerminated)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
