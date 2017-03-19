import Foundation

public protocol ServerContext {
    
    associatedtype Config
    associatedtype Client
    associatedtype Request
    associatedtype Response
    associatedtype Message
    
    func initialize(config: Config?) -> ServerInit<Self>
    func onSync(client: Client?,
                request: Request,
                execute: (Response?) -> Void) -> ServerSync<Self>
    func onAsync(client: Client, request: Request) -> ServerAsync<Self>
    func onTerminate(error: Error)
    
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
    
    case sync(client: Context.Client?,
        request: Context.Request,
        timeout: UInt,
        execute: (Context.Response?) -> Void)
    case terminate(error: Error, timeout: UInt?)
    
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
                           execute: let execute):
                    var wait = true
                    let waitExecute: (Context.Response?) -> Void = { response in
                        wait = false
                        execute(response)
                    }
                    let timeoutExecute: (UInt) -> Void = { timeout in
                        p.asyncAfter(deadline: timeout) {
                            if wait {
                                self.terminate(error: ServerError.timeout)
                            }
                        }
                    }
                    timeoutExecute(timeout)
                    
                    switch self.context.onSync(client: client,
                                               request: request,
                                               execute: waitExecute) {
                    case .wait(timeout: let timeout):
                        if let timeout = timeout {
                            timeoutExecute(timeout)
                        }
                        while wait {}
                        
                    case .await(timeout: let timeout):
                        if let timeout = timeout {
                            timeoutExecute(timeout)
                        }
                        break
                        
                    case .terminate(error: let error):
                        self.terminate(error: error)
                    }
                    
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
        self.context.onTerminate(error: error)
    }
    
    public func terminateAfter(deadline: UInt, error: Error) {
        parcel.terminateAfter(deadline: deadline) {
            self.context.onTerminate(error: error)
        }
    }
    
    // MARK: Sending Requests
    
    public func sync(client: Context.Client? = nil,
                     request: Context.Request,
                     timeout: UInt = 5000) throws -> Context.Response? {
        var result: Context.Response?
        do {
            try parcel.waitForStop(timeout: timeout) { timer in
                let execute: (Context.Response?) -> Void = { response in
                    result = response
                    timer.stop()
                }
                self.parcel ! .sync(client: client,
                                    request: request,
                                    timeout: timeout,
                                    execute: execute)
            }
        } catch ParcelTimer.Error.timeout {
            throw ServerError.timeout
        }
        return result
    }
    
    public func async(request: Context.Request) {
        
    }
    
}
