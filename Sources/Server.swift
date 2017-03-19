import Foundation

public protocol ServerContext {
    
    associatedtype Config
    associatedtype Client
    associatedtype Request
    associatedtype Response
    associatedtype Message
    
    func initialize(server: Server<Self>, config: Config?) -> ServerInit<Self>
    func onSync(server: Server<Self>,
                client: Client?,
                request: Request,
                operation: ServerSyncOperation<Self>)
    func onAsync(server: Server<Self>,
                 client: Client,
                 request: Request) -> ServerAsync<Self>
    func onTerminate(server: Server<Self>, error: Error)
    
}

public enum ServerInit<Context> where Context: ServerContext {
    case ok(timeout: UInt?)
    case terminate(error: Error)
    case ignore
}

public enum ServerSync<Context> where Context: ServerContext {
    case wait(timeout: UInt?)
    case await(timeout: UInt?)
    case terminate(error: Error)
}

public enum ServerAsync<Context> where Context: ServerContext {
    case ignore(timeout: UInt?)
    case terminate(error: Error)
}

public enum ServerRun<Context> where Context: ServerContext {
    case ok(Parcel<Context.Message>)
    case ignore
    case error(Error)
}

public enum ServerError: Error {
    
    case normal
    case timeout
    
}

public struct ServerOption {
    
    public var timeout: UInt?
    
}

public enum ServerOperation<Context> where Context: ServerContext {
    
    case terminate(error: Error, timeout: UInt?)
    
}

public class ServerSyncOperation<Context> where Context: ServerContext {
    
    weak var server: Server<Context>!
    var responseToReturn: Context.Response?
    var waitQueue: DispatchQueue
    var complete: Bool = false
    var isTimeout: Bool = false
    var syncTimer: Timer?
    var error: Error?
    
    init(server: Server<Context>) {
        self.server = server
        waitQueue = DispatchQueue(label: "ParcelSyncOperation")
    }
    
    func waitForReturn(client: Context.Client?,
                       request: Context.Request,
                       timeout: UInt?) throws {
        if let timeout = timeout {
            updateSyncTimer(timeout: timeout)
        }
        waitQueue.async {
            self.server.context.onSync(server: self.server,
                                       client: client,
                                       request: request,
                                       operation: self)
        }
        while !complete {}
        syncTimer?.invalidate()
        if let error = error {
            throw error
        }
    }
    
    func updateSyncTimer(timeout: UInt) {
        syncTimer?.invalidate()
        let interval: Double = Double(timeout) / 1000
        if #available(OSX 10.12, *) {
            syncTimer = Timer(timeInterval: interval,
                              repeats: false)
            { timer in
                if !self.complete {
                    self.error = ServerError.timeout
                    self.complete = true
                }
            }
        } else {
            // Fallback on earlier versions
            assertionFailure()
        }
    }
    
    public func yield(timeout: UInt? = nil) {
        complete = false
        if let timeout = timeout {
            updateSyncTimer(timeout: timeout)
        }
    }
    
    public func `return`(response: Context.Response? = nil,
                         timeout: UInt? = nil) {
        responseToReturn = response
        complete = true
    }
    
}

open class Server<Context> where Context: ServerContext {
    
    typealias Operation = ServerOperation<Context>
    
    public var context: Context
    var parcel: Parcel<Operation>!
    var syncQueue: DispatchQueue
    
    public init(context: Context) {
        self.context = context
        syncQueue = DispatchQueue(label: "Server")
    }
    
    // MARK: Running Servers
    
    public func run(config: Context.Config? = nil,
                    options: ServerOption? = nil) -> Error? {
        switch context.initialize(server: self, config: config) {
        case .ignore:
            break
        default:
            break
        }
        
        parcel = Parcel<Operation>.spawn { p in
            p.onReceive { message in
                switch message {
                case .terminate(error: let error, timeout: let timeout):
                    if let timeout = timeout {
                        self.terminateAfter(deadline: timeout, error: error)
                    } else {
                        self.terminate(error: error)
                    }
                }
                
                return .continue
            }
        }
        
        // TODO
        return nil
    }
    
    public func runUnderSupervision(config: Context.Config? = nil,
                                    options: ServerOption? = nil) -> Error? {
        // TODO
        return nil
    }
    
    public func terminate(error: Error) {
        parcel.terminate()
        self.context.onTerminate(server: self, error: error)
    }
    
    public func terminateAfter(deadline: UInt, error: Error) {
        parcel.terminateAfter(deadline: deadline) {
            self.context.onTerminate(server: self, error: error)
        }
    }
    
    // MARK: Sending Requests
    
    public func sync(client: Context.Client? = nil,
                     request: Context.Request,
                     timeout: UInt = 5000) throws -> Context.Response? {
        let op = ServerSyncOperation<Context>(server: self)
        do {
            try op.waitForReturn(client: client,
                                 request: request,
                                 timeout: timeout)
        } catch let e {
            throw e
        }
        return op.responseToReturn
    }
    
    public func async(request: Context.Request) {
        
    }
    
}
