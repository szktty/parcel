import Foundation

public protocol ServerContext {
    
    associatedtype Config
    associatedtype Request
    associatedtype Response
    associatedtype Message
    associatedtype Error
    
    func initialize(config: Config) -> ServerInitResult<Self>
    func onSendSync(client: Parcel<Response>, request: Request) -> ServerSendSyncResult<Self>
    func onSendAsync(client: Parcel<Response>, request: Request) -> ServerSendAsyncResult<Self>
    func terminate(client: Parcel<Response>, error: Error?)
    
}

public enum ServerInitResult<Context> where Context: ServerContext {
    case ok(timeout: Int?)
    case stop(Context.Error)
    case ignore
}

public enum ServerSendSyncResult<Context> where Context: ServerContext {
    case response(timeout: Int?, response: Context.Response?)
    case ignore(timeout: Int?)
    case stop(error: Context.Error, response: Context.Response?)
}

public enum ServerSendAsyncResult<Context> where Context: ServerContext {
    case ignore(timeout: Int?)
    case stop(error: Context.Error)
}

public enum ServerReceiveResult<Context> where Context: ServerContext {
    case ignore(timeout: Int?)
    case stop(error: Context.Error)
}

public enum ServerRunResult<Context> where Context: ServerContext {
    case ok(Parcel<Context.Message>)
    case ignore
    case error(Context.Error)
}

public struct ServerOption {
    
    public var timeout: Int?
    
}

public enum ServerOperation<Context> where Context: ServerContext {
    case sendSync(client: Parcel<Context.Response>, request: Context.Request)
}

open class Server<Context> where Context: ServerContext {

    typealias Operation = ServerOperation<Context>
    
    public var context: Context
    var parcel: Parcel<Operation>?
    var lockQueue: DispatchQueue
    
    public init(context: Context) {
        self.context = context
        lockQueue = DispatchQueue(label: "Server")
    }
    
    // MARK: Running Servers
    
    public func run(config: Context.Config) {
        switch context.initialize(config: config) {
        case .ignore:
            break
        default:
            break
        }
        
        parcel = Parcel<Operation>.spawn { p in
            p.onReceive { message in
                switch message {
                case .sendSync(client: let client, request: let request):
                    switch self.context.onSendSync(client: client, request: request) {
                    case .ignore(timeout: let timeout):
                        break
                    default:
                        break
                    }
                    break
                }
                return .continue
            }
        }
    }
    
    /*
    public func runAndLink(config: Context.Config, options: ServerOption) -> ServerRunResult<Context> {
        return .ignore
    }
 */

    public func stop(error: Error? = nil, timeout: Int? = nil) {
        
    }
    
    // MARK: Sending Requests
    
    public func sendSync(client: Parcel<Context.Response>, request: Context.Request, timeout: Int? = nil) -> Context.Response? {
        guard let parcel = parcel else {
            assertionFailure("not running")
            return nil
        }
        parcel ! .sendSync(client: client, request: request)
        return nil
    }
    
    public func sendAsync(request: Context.Request) {
        
    }
    
    // MARK: Sending Values to Clients
    
    public func sendResponse(client: Parcel<Context.Response>, response: Context.Response) {
    }
    
}
