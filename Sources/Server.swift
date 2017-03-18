import Foundation

public protocol ServerContext {
    
    associatedtype Config
    associatedtype Client
    associatedtype Request
    associatedtype Response
    associatedtype Message
    associatedtype Error
    
    func initialize(config: Config?) -> ServerInit<Self>
    func onSync(client: Client?,
                request: Request,
                execute: (Response) -> Void) -> ServerSync<Self>
    func onAsync(client: Client, request: Request) -> ServerAsync<Self>
    func onTerminate(error: ServerError<Self>)
    
}

public enum ServerInit<Context> where Context: ServerContext {
    case ok(timeout: UInt?)
    case terminate(error:ServerError<Context>)
    case ignore
}

public enum ServerSync<Context> where Context: ServerContext {
    case wait(timeout: UInt?)
    case await(timeout: UInt?)
    case terminate(error: ServerError<Context>)
}

public enum ServerAsync<Context> where Context: ServerContext {
    case ignore(timeout: UInt?)
    case terminate(error: ServerError<Context>)
}

public enum ServerRun<Context> where Context: ServerContext {
    case ok(Parcel<Context.Message>)
    case ignore
    case error(ServerError<Context>)
}

public enum ServerError<Context>: Error where Context: ServerContext {
    
    case normal
    case timeout
    case error(Error)
    case context(Context.Error)
    
}

public struct ServerOption {
    
    public var timeout: UInt?
    
}

public enum ServerOperation<Context> where Context: ServerContext {
    
    case sync(client: Context.Client?,
        request: Context.Request,
        timeout: UInt?,
        block: (Context.Response) -> Void)
    case terminate(error: ServerError<Context>, timeout: UInt?)
    
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
        switch context.initialize(config: config) {
        case .ignore:
            break
        default:
            break
        }
        
        parcel = Parcel<Operation>.spawn { p in
            p.onReceive { message in
                switch message {
                case .sync(client: let client,
                           request: let request,
                           timeout: let timeout,
                           block: let block):
                    var sync = true
                    let callback: (Context.Response) -> Void = { response in
                        sync = false
                        block(response)
                    }
                    switch self.context.onSync(client: client,
                                               request: request,
                                               execute: callback) {
                    case .wait(timeout: let timeout):
                        while sync {}
                        
                    case .await(timeout: let timeout):
                        break
                        
                    case .terminate(error: let error):
                        self.terminate(error: error)
                    }
                    
                case .terminate(error: let error, timeout: let timeout):
                    if let deadline = timeout {
                        self.terminateAfter(deadline: deadline, error: error)
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
    
    public func terminate(error: ServerError<Context>) {
        parcel.terminate()
        self.context.onTerminate(error: error)
    }
    
    public func terminateAfter(deadline: UInt, error: ServerError<Context>) {
        parcel.terminateAfter(deadline: deadline) {
            self.context.onTerminate(error: error)
        }
    }
    
    // MARK: Sending Requests
    
    public func sync(client: Context.Client? = nil,
                     request: Context.Request,
                     timeout: UInt? = nil) -> Context.Response {
        assert(parcel != nil)
        var returnValue: Context.Response?
        let block: (Context.Response) -> Void = { response in
            returnValue = response
        }
        parcel ! .sync(client: client,
                       request: request,
                       timeout: timeout,
                       block: block)
        while returnValue == nil {}
        return returnValue!
    }
    
    public func async(request: Context.Request) {
        
    }
    
}
