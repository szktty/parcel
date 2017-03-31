import Foundation
import BrightFutures
import Result

public typealias SyncFuture<Value> = Future<Value, SyncError>

public enum SyncError: Error {
    
    case asyncOnly
    case timeout
    
}

struct SyncMessage<Message, Value> {

    var message: Message
    var complete: ((Result<Value, SyncError>) -> Void)?
    
}

public final class SyncParcel<Message, Value>: BasicParcel {
    
    public typealias Complete = (Result<Value, SyncError>) -> Void
    
    private var parcel: Parcel<SyncMessage<Message, Value>>!
    
    private var onReceiveHandler: ((Message, Complete?) throws -> Loop)?
    
    // MARK: Initialization
    
    public required override init() {
        super.init()
        parcel = Parcel<SyncMessage<Message, Value>>()
        parcel.onReceive { message in
            if let handler = self.onReceiveHandler {
                return try handler(message.message, message.complete)
            } else {
                return .break
            }
        }
    }
    
    // MARK: Event handlers
    
    public func onReceive(handler: @escaping (Message, Complete?) throws -> Loop) {
        onReceiveHandler = handler
    }
    
    // MARK: Running
    
    public func run() {
        parcel.run()
    }
    
    public class func spawn(block: @escaping (SyncParcel<Message, Value>) -> Void) -> SyncParcel<Message, Value> {
        let syncParcel: SyncParcel<Message, Value> = self.init()
        block(syncParcel)
        syncParcel.run()
        return syncParcel
    }
    
    // MARK: Message passing
    
    public func async(message: Message) {
        parcel ! SyncMessage(message: message, complete: nil)
    }
    
    public func sync(message: Message) -> SyncFuture<Value> {
        return SyncFuture<Value> { complete in
            let syncMessage = SyncMessage<Message, Value>(message: message,
                                                          complete: complete)
            parcel ! syncMessage
        }
    }
    
}

// MARK: - Operators

infix operator !!

public func !<Message, Value>(lhs: SyncParcel<Message, Value>, rhs: Message) {
    lhs.async(message: rhs)
}

public func !!<Message, Value>(lhs: SyncParcel<Message, Value>, rhs: Message) -> SyncFuture<Value> {
    return lhs.sync(message: rhs)
}
