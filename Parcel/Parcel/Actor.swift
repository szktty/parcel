import Foundation

public class Actor<T> {

    public weak var context: ActorContext<T>!
    var messageHandler: (ActorContext<T>, T) -> ()
    // TODO: timeout handler
    
    public required init(messageHandler: @escaping (ActorContext<T>, T) -> ()) {
        self.messageHandler = messageHandler
    }
    
    // subclasses can override instead of using the message handler
    public func receive(_ message: T) {
        messageHandler(context, message)
    }
    
    public class func spawn(messageHandler: @escaping (ActorContext<T>, T) -> ()) -> ActorContext<T> {
        let actor = self.init(messageHandler: messageHandler)
        Scheduler.default.add(actor: actor)
        return actor.context
    }
    
}
