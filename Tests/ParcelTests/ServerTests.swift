import XCTest
@testable import Parcel

final class MyBankContext: ServerContext {
    
    public typealias Config = Void
    public typealias Client = Void
    public typealias Message = String
    public typealias Response = Void
    
    enum Request {
        case new(who: String)
        case add(who: String, amount: Int)
        case remove(who: String, amount: Int)
        case stop
    }
    
    var clients: [String: Int] = [:]
    
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
            receiver.update(timeout: 1)
            receiver.return()
            
        case .add(who: let who, amount: let amount):
            if let balance = clients[who] {
                clients[who] = balance + amount
            }
            receiver.return()
            
        case .remove(who: let who, amount: let amount):
            if let balance = clients[who] {
                clients[who] = balance - amount
            }
            receiver.return()
            
        case .stop:
            receiver.terminate(error: ServerError.normal)
        }
    }
    
    func onAsync(server: Server<MyBankContext>,
                 client: Client, request: Request)
        -> ServerAsync<MyBankContext>
    {
        return .ignore(timeout: nil)
    }
    
    func onTerminate(server: Server<MyBankContext>, error: Error) {
        
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
        try! server.sync(request: .stop)
    }
    
    func newAccount(who: String) {
        do {
            try server.sync(request: .new(who: who))
        } catch let e {
            print("newAccount error:", e)
            assertionFailure()
        }
    }
    
    func deposit(who: String, amount: Int) {
        do {
            try server.sync(request: .add(who: who, amount: amount))
        } catch let e {
            print("deposit error:", e)
            assertionFailure()
        }
    }
    
    func withdraw(who: String, amount: Int) {
        do {
            try server.sync(request: .remove(who: who, amount: amount))
        } catch let e {
            print("withdraw error:", e)
            assertionFailure()
        }
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
        bank.newAccount(who: joe)
        bank.deposit(who: joe, amount: 10)
        bank.stop()
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
