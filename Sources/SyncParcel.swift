import Foundation
import BrightFutures

public typealias SyncFuture<Reply> = Future<Reply, SyncError>

public enum SyncError: Error {
    
    case asyncOnly
    case timeout
    
}

struct SyncMessage<Message, Reply> {

    var message: Message
    var future: SyncFuture<Reply>?
    
}

public final class SyncParcel<Message, Reply>: BasicParcel {
    
    var parcel: Parcel<SyncMessage<Message, Reply>>!
    
    var onReceiveHandler: ((Message, SyncFuture<Reply>?) throws -> Loop)?
    
    // MARK: Initialization
    
    public required override init() {
        super.init()
        parcel = Parcel<SyncMessage<Message, Reply>>()
        parcel.onReceive { message in
            if let handler = self.onReceiveHandler {
                return try handler(message.message, message.future)
            } else {
                return .break
            }
        }
    }
    
    // MARK: Event handlers
    
    public func onReceive(handler: @escaping (Message, SyncFuture<Reply>?) throws -> Loop) {
        onReceiveHandler = handler
    }
    
    // MARK: Running
    
    public func run() {
        parcel.run()
    }
    
    public class func spawn(block: @escaping (SyncParcel<Message, Reply>) -> Void) -> SyncParcel<Message, Reply> {
        let syncParcel: SyncParcel<Message, Reply> = self.init()
        block(syncParcel)
        syncParcel.run()
        return syncParcel
    }
    
    // MARK: Message passing
    
    public func async(message: Message) {
        parcel ! SyncMessage(message: message, future: nil)
    }
    
    public func sync(message: Message) -> SyncFuture<Reply> {
        let future = SyncFuture<Reply>()
        let syncMessage = SyncMessage<Message, Reply>(message: message,
                                                      future: future)
        parcel ! syncMessage
        return future
    }
    
}

// MARK: - Operators

infix operator !!

public func !<Message, Reply>(lhs: SyncParcel<Message, Reply>, rhs: Message) {
    lhs.async(message: rhs)
}

public func !!<Message, Reply>(lhs: SyncParcel<Message, Reply>, rhs: Message) -> SyncFuture<Reply> {
    return lhs.sync(message: rhs)
}
