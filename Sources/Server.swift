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
    func terminate(error: Error)
    
}

public enum ServerInitResult<Context> where Context: ServerContext {
    case ok(timeout: Int?)
    case terminate(Context.Error)
    case ignore
}

public enum ServerSendSyncResult<Context> where Context: ServerContext {
    case response(response: Context.Response, timeout: Int?)
    case ignore(timeout: Int?)
    case terminate(error: Context.Error)
}

public enum ServerSendAsyncResult<Context> where Context: ServerContext {
    case ignore(timeout: Int?)
    case terminate(error: Context.Error)
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
    var parcel: Parcel<Operation>!
    var waitingValues: [ObjectIdentifier: Context.Response] = [:]
    var waitingErrors: [ObjectIdentifier: Context.Error] = [:]
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
                    case .response(response: let response, timeout: let timeout):
                        self.waitingValues[client.id] = response

                    case .ignore(timeout: let timeout):
                        break

                    case .terminate(error: let error):
                        self.waitingErrors[client.id] = error
                    }
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

    public func terminate(error: Context.Error, timeout: Int? = nil) {
        context.terminate(error: error)
    }
    
    // MARK: Sending Requests
    
    public func sendSync(client: Parcel<Context.Response>, request: Context.Request, timeout: Int? = nil) -> Context.Response {
        assert(parcel != nil)
        
        var response: Context.Response!
        lockQueue.sync {
            parcel ! .sendSync(client: client, request: request)
            while true {
                if let value = self.waitingValues[client.id] {
                    response = value
                    self.waitingValues[client.id] = nil
                    if let error = self.waitingErrors[client.id] {
                        self.waitingErrors[client.id] = nil
                        self.terminate(error: error)
                    }
                    break
                }
            }
        }
        return response
    }
    
    public func sendAsync(request: Context.Request) {
        
    }
    
    // MARK: Sending Values to Clients
    
    public func sendResponse(client: Parcel<Context.Response>, response: Context.Response) {
        client ! response
        waitingValues[client.id] = response
    }
    
}
