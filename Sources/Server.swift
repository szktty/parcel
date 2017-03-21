import Foundation
import Result

public protocol ServerContext {
    
    associatedtype Config
    associatedtype Client
    associatedtype Request
    associatedtype Response
    
    func initialize(server: Server<Self>, config: Config?) -> ServerInit<Self>
    func onSync(server: Server<Self>,
                client: Client?,
                request: Request,
                receiver: ServerResponseReceiver<Self>)
    func onAsync(server: Server<Self>,
                 client: Client?,
                 request: Request,
                 receiver: ServerResponseReceiver<Self>)
    func onTerminate(server: Server<Self>, error: Error)
    
}

public enum ServerInit<Context> where Context: ServerContext {
    case ok(timeout: UInt?)
    case terminate(error: Error)
    case ignore
}

public enum ServerRun<Context> where Context: ServerContext {
    //case ok(Parcel<Context.Message>)
    case ignore
    case error(Error)
}

public enum ServerError: Error {
    
    case normal
    case timeout
    case user(Error)
    
}

public struct ServerOption {
    
    public var timeout: UInt?
    
}

enum ServerRequest<Context> where Context: ServerContext {
    
    case sync(client: Context.Client?,
        request: Context.Request,
        receiver: ServerResponseReceiver<Context>)
    case async(client: Context.Client?,
        request: Context.Request,
        receiver: ServerResponseReceiver<Context>)

}

public class ServerResponseReceiver<Context> where Context: ServerContext {
    
    weak var server: Server<Context>!
    var responseToReturn: Context.Response?
    var isFinished: Bool = false
    var isTimeout: Bool = false
    var isTerminated: Bool = false
    var timerWorkItem: DispatchWorkItem?
    var error: ServerError?
    
    init(server: Server<Context>) {
        self.server = server
    }
    
    public func update(timeout: UInt) {
        timerWorkItem?.cancel()
        guard let worker = server.parcel.worker else { return }
        timerWorkItem = DispatchWorkItem {
            worker.asyncAfter(parcel: self.server.parcel,
                              deadline: timeout)
            {
                self.isTimeout = true
            }
        }
        worker.executeQueue.async(execute: timerWorkItem!)
    }
    
    public func `return`(response: Context.Response? = nil) {
        responseToReturn = response
        isFinished = true
    }
    
    public func terminate(error: ServerError) {
        self.error = error
        isTerminated = true
        isFinished = true
    }
    
}

open class Server<Context> where Context: ServerContext {
    
    public var context: Context
    var parcel: Parcel<ServerRequest<Context>>!
    
    public init(context: Context) {
        self.context = context
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
        
        parcel = Parcel<ServerRequest<Context>>.spawn { p in
            p.onReceive { servReq in
                var isTerminated: Bool = false
                var error: Error!
                
                switch servReq {
                case .sync(client: let client,
                           request: let request,
                           receiver: let receiver):
                    self.context.onSync(server: self,
                                        client: client,
                                        request: request,
                                        receiver: receiver)
                    isTerminated = receiver.isTerminated
                    error = receiver.error
                    
                case .async(client: let client,
                            request: let request,
                            receiver: let receiver):
                    self.context.onAsync(server: self,
                                         client: client,
                                         request: request,
                                         receiver: receiver)
                    isTerminated = receiver.isTerminated
                    error = receiver.error
                }
                
                if isTerminated {
                    self.context.onTerminate(server: self, error: error)
                    return .break
                } else {
                    return .continue
                }
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
                     timeout: UInt = 5000)
        -> Result<Context.Response?, ServerError>
    {
        let receiver = ServerResponseReceiver<Context>(server: self)
        let servReq = ServerRequest<Context>.sync(client: client,
                                                  request: request,
                                                  receiver: receiver)
        receiver.update(timeout: timeout)
        parcel ! servReq
        while !receiver.isFinished && !receiver.isTimeout {}
        if receiver.isTimeout {
            return .failure(ServerError.timeout)
        } else if let error = receiver.error {
            return .failure(error)
        } else {
            return .success(receiver.responseToReturn)
        }
    }
    
    public func async(client: Context.Client? = nil,
                      request: Context.Request) {
        let receiver = ServerResponseReceiver<Context>(server: self)
        let servReq = ServerRequest<Context>.async(client: client,
                                                   request: request,
                                                   receiver: receiver)
        parcel ! servReq
    }
    
}
