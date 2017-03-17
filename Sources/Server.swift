import Foundation

public protocol ServerContext {
    
    associatedtype Config
    associatedtype Client
    associatedtype Request
    associatedtype Response
    associatedtype Message
    associatedtype Error
    
    func initialize(config: Config?) -> ServerInit<Self>
    func onSendSync(client: Client?,
                    request: Request,
                    block: (Response) -> Void) -> ServerSendSync<Self>
    func onSendAsync(client: Client, request: Request) -> ServerSendAsync<Self>
    func onTerminate(error: Error)
    
}

public enum ServerInit<Context> where Context: ServerContext {
    case ok(timeout: Int?)
    case terminate(Context.Error)
    case ignore
}

public enum ServerSendSync<Context> where Context: ServerContext {
    case sync(timeout: Int?)
    case async(timeout: Int?)
    case terminate(error: Context.Error)
}

public enum ServerSendAsync<Context> where Context: ServerContext {
    case ignore(timeout: Int?)
    case terminate(error: Context.Error)
}

public enum ServerRun<Context> where Context: ServerContext {
    case ok(Parcel<Context.Message>)
    case ignore
    case error(Context.Error)
}

public struct ServerOption {
    
    public var timeout: Int?
    
}

public enum ServerOperation<Context> where Context: ServerContext {
    
    case sendSync(client: Context.Client?,
        request: Context.Request,
        timeout: Int?,
        block: (Context.Response) -> Void)
    case terminate(error: Context.Error)
    
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
    
    public func run(config: Context.Config? = nil) {
        switch context.initialize(config: config) {
        case .ignore:
            break
        default:
            break
        }
        
        parcel = Parcel<Operation>.spawn { p in
            p.onReceive { message in
                switch message {
                case .sendSync(client: let client,
                               request: let request,
                               timeout: let timeout,
                               block: let block):
                    var sync = true
                    let callback: (Context.Response) -> Void = { response in
                        sync = false
                        block(response)
                    }
                    switch self.context.onSendSync(client: client,
                                                   request: request,
                                                   block: callback) {
                    case .sync(timeout: let timeout):
                        while sync {}

                    case .async(timeout: let timeout):
                        break

                    case .terminate(error: let error):
                        // TODO
                        self.terminate(error: error)
                    }
                    return .continue

                case .terminate(error: let error):
                    return .break
                }
            }
        }
    }
    
    /*
    public func runAndLink(config: Context.Config, options: ServerOption) -> ServerRun<Context> {
        return .ignore
    }
 */

    public func terminate(error: Context.Error, timeout: Int? = nil) {
        context.onTerminate(error: error)
        parcel ! .terminate(error: error)
    }
    
    // MARK: Sending Requests
    
    public func sendSync(client: Context.Client? = nil,
                         request: Context.Request,
                         timeout: Int? = nil) -> Context.Response {
        assert(parcel != nil)
        var returnValue: Context.Response?
        let block: (Context.Response) -> Void = { response in
            returnValue = response
        }
        parcel ! .sendSync(client: client,
                           request: request,
                           timeout: timeout,
                           block: block)
        while returnValue == nil {}
        return returnValue!
    }
    
    public func sendAsync(request: Context.Request) {
        
    }
    
}
