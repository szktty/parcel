import Foundation

public protocol ServerBehavior {
    
    associatedtype Config
    associatedtype Request
    associatedtype State
    associatedtype Message
    associatedtype Reply
    associatedtype Error
    
    func initialize(config: Config) -> ServerInitResult<Self>
    func onSendSync(state: State, request: Request, from: Parcel<Message>) -> ServerSendSyncResult<Self>
    func onSendAsync(state: State, request: Request) -> ServerSendAsyncResult<Self>
    func onReceive(state: State, message: Message) -> ServerReceiveResult<Self>
    func terminate(state: State, error: Error?)
    
}

public enum ServerInitResult<Behavior> where Behavior: ServerBehavior {
    case ok(state: Behavior.State, timeout: Int?)
    case stop(Behavior.Error)
    case ignore
}

public enum ServerSendSyncResult<Behavior> where Behavior: ServerBehavior {
    case reply(state: Behavior.State, timeout: Int?, reply: Behavior.Reply?)
    case noreply(state: Behavior.State, timeout: Int?)
    case stop(state: Behavior.State, error: Behavior.Error, reply: Behavior.Reply?)
}

public enum ServerSendAsyncResult<Behavior> where Behavior: ServerBehavior {
    case noreply(state: Behavior.State, timeout: Int?)
    case stop(state: Behavior.State, error: Behavior.Error)
}

public enum ServerReceiveResult<Behavior> where Behavior: ServerBehavior {
    case noreply(state: Behavior.State, timeout: Int?)
    case stop(state: Behavior.State, error: Behavior.Error)
}

public enum ServerRunResult<Behavior> where Behavior: ServerBehavior {
    case ok(Parcel<Behavior.Message>)
    case ignore
    case error(Behavior.Error)
}

public struct ServerOption {
    
    public var timeout: Int?
    
}

open class Server<Behavior> where Behavior: ServerBehavior {
    
    public var behavior: Behavior
    
    public init(behavior: Behavior) {
        self.behavior = behavior
    }
    
    // MARK: Running Servers
    
    public func run(config: Behavior.Config) {
        let _ = behavior.initialize(config: config)
    }
    
    public func runAndLink(config: Behavior.Config, options: ServerOption) -> ServerRunResult<Behavior> {
        return .ignore
    }

    public func stop(error: Error? = nil, timeout: Int? = nil) {
        
    }
    
    // MARK: Sending Requests
    
    public func sendSync(request: Behavior.Request, timeout: Int? = nil) -> Behavior.Reply? {
        return nil
    }
    
    public func sendAsync(request: Behavior.Request) {
        
    }
    
    // MARK: Sending Values to Clients
    
    public func sendReply(client: Parcel<Behavior.Message>, value: Behavior.Reply) {
        
    }
    
}
