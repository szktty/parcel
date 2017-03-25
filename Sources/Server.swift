import Foundation
import Result

public protocol ServerDelegate {
    
    associatedtype Config
    associatedtype Client
    associatedtype Request
    associatedtype Response
    
    func initialize(server: Server<Self>, config: Config?) -> ServerInitResult
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

public enum ServerInitResult {
    
    case ok(timeout: UInt?)
    case terminate(error: Error)
    case ignore
    
}

public enum ServerRunResult {
    
    case ok
    case ignore
    case error(Error)
    
}

public enum ServerError: Error {
    
    case normal
    case timeout
    case alreadyRunning
    case other(Error)
    
}

public struct ServerOption {
    
    public var timeout: UInt?
    
}

enum ServerRequest<Delegate> where Delegate: ServerDelegate {
    
    case sync(client: Delegate.Client?,
        request: Delegate.Request,
        receiver: ServerResponseReceiver<Delegate>)
    case async(client: Delegate.Client?,
        request: Delegate.Request,
        receiver: ServerResponseReceiver<Delegate>)

}

public class ServerResponseReceiver<Delegate> where Delegate: ServerDelegate {
    
    weak var server: Server<Delegate>!
    var responseToReturn: Delegate.Response?
    var isReturned: Bool = false
    var isFinished: Bool = false
    var isTimeout: Bool = false
    var isTerminated: Bool = false
    var timerWorkItem: DispatchWorkItem?
    var error: ServerError?
    
    init(server: Server<Delegate>) {
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
    
    public func `return`(response: Delegate.Response? = nil) {
        responseToReturn = response
        isReturned = true
    }
    
    public func terminate(error: ServerError) {
        self.error = error
        isTerminated = true
        isReturned = true
    }
    
    func finish() -> Loop {
        if isTerminated {
            server.delegate.onTerminate(server: server, error: error!)
            isFinished = true
            return .break
        } else {
            isFinished = true
            return .continue
        }
    }
    
}

open class Server<Delegate> where Delegate: ServerDelegate {
    
    public var delegate: Delegate
    var parcel: Parcel<ServerRequest<Delegate>>!
    var requestWaitTimer: DispatchWorkItem?
    
    public init(delegate: Delegate) {
        self.delegate = delegate
    }
    
    // MARK: Running Servers
    
    public func run(config: Delegate.Config? = nil,
                    options: ServerOption? = nil) -> ServerRunResult {
        if parcel != nil {
            return .error(ServerError.alreadyRunning)
        }
        
        switch delegate.initialize(server: self, config: config) {
        case .ignore:
            break
        case .terminate(error: let error):
            return .error(error)
        case .ok(timeout: let timeout):
            if let timeout = timeout {
                requestWaitTimer = parcel.dispatchQueue.asyncAfter(timeout: timeout) {
                    self.terminate(error: ServerError.timeout)
                }
            }
        }
        
        parcel = Parcel<ServerRequest<Delegate>>.spawn { p in
            p.onReceive { servReq in
                self.requestWaitTimer?.cancel()
                switch servReq {
                case .sync(client: let client,
                           request: let request,
                           receiver: let receiver):
                    self.delegate.onSync(server: self,
                                        client: client,
                                        request: request,
                                        receiver: receiver)
                    return receiver.finish()
                    
                case .async(client: let client,
                            request: let request,
                            receiver: let receiver):
                    self.delegate.onAsync(server: self,
                                         client: client,
                                         request: request,
                                         receiver: receiver)
                    return receiver.finish()
                }
            }
        }
        
        return .ok
    }
    
    public func runUnderSupervision(config: Delegate.Config? = nil,
                                    options: ServerOption? = nil) -> Error? {
        // TODO
        return nil
    }
    
    public func terminate(error: Error) {
        delegate.onTerminate(server: self, error: error)
        parcel.terminate()
    }
    
    public func terminateAfter(deadline: UInt, error: Error) {
        parcel.terminateAfter(deadline: deadline) {
            self.delegate.onTerminate(server: self, error: error)
        }
    }
    
    // MARK: Sending Requests
    
    public func sync(client: Delegate.Client? = nil,
                     request: Delegate.Request,
                     timeout: UInt = 5000)
        -> Result<Delegate.Response?, ServerError>
    {
        let receiver = ServerResponseReceiver<Delegate>(server: self)
        let servReq = ServerRequest<Delegate>.sync(client: client,
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
    
    public func async(client: Delegate.Client? = nil,
                      request: Delegate.Request) {
        let receiver = ServerResponseReceiver<Delegate>(server: self)
        let servReq = ServerRequest<Delegate>.async(client: client,
                                                   request: request,
                                                   receiver: receiver)
        parcel ! servReq
    }
    
}
