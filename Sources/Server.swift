import Foundation

public protocol ServerBehavior {
    
    associatedtype Config
    associatedtype Request
    associatedtype State
    associatedtype Message
    associatedtype Reply
    
    func initialize(config: Config) -> ServerInitResult<Self>
    func onCall(state: State, request: Request, from: Parcel<Message>) -> ServerCallResult<Self>
    func onCast(state: State, request: Request) -> ServerCastResult<Self>
    func onReceive(state: State, message: Message) -> ServerCastResult<Self>
    func terminate(state: State, error: Error?)
    
}

public enum ServerInitResult<Behavior> where Behavior: ServerBehavior {
    case ok(state: Behavior.State, timeout: Int?)
    case stop(Error)
    case ignore
}

public enum ServerCallResult<Behavior> where Behavior: ServerBehavior {
    case reply(state: Behavior.State, timeout: Int?, reply: Behavior.Reply?)
    case noreply(state: Behavior.State, timeout: Int?)
    case stop(state: Behavior.State, error: Error, reply: Behavior.Reply?)
}

public enum ServerCastResult<Behavior> where Behavior: ServerBehavior {
    case noreply(state: Behavior.State, timeout: Int?)
    case stop(state: Behavior.State, error: Error)
}

open class Server<Behavior> where Behavior: ServerBehavior {
    
    public var behavior: Behavior
    
    public init(behavior: Behavior) {
        self.behavior = behavior
    }
    
    public func run(config: Behavior.Config) {
        let _ = behavior.initialize(config: config)
    }
    
}
