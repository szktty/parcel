import Foundation

public enum ActorError: Error {
    case unspawned
    case death(BasicActor)
    case user(Error)
}

public enum Loop {
    case `continue`
    case `break`
    case timeout
}

public class BasicActor {
    
    public var id: ObjectIdentifier {
        get { return ObjectIdentifier(self) }
    }
    
    weak var worker: Worker?
    var deadline: DispatchTime?
    var timeoutHandler: (() -> Void)?
    var isAlive: Bool = true
    var timeoutForced: Bool = false
    var onErrorHandler: ((Error) -> Void)?
    var onDeathHandler: ((ActorError) -> Void)?

    public func after(deadline: DispatchTime, handler: @escaping () -> Void) {
        self.deadline = deadline
        timeoutHandler = handler
    }
    
    public func onError(handler: @escaping (Error) -> Void) {
        onErrorHandler = handler
    }
    
    public func onDeath(handler: @escaping (ActorError) -> Void) {
        onDeathHandler = handler
    }
    
    public func terminate() {
        isAlive = false
    }
    
    func handle(error: Error) {
        terminate()
        onErrorHandler?(error)
    }
    
}

public class Actor<T>: BasicActor {

    public var userInfo: [String: Any] = [:]
    
    var onReceiveHandler: ((T) throws -> Loop)?
    var messageQueue: MessageQueue<T>!

    public required override init() {
        super.init()
        messageQueue = MessageQueue(actor: self)
    }
    
    // MARK: Event handlers
    
    public func onReceive(handler: @escaping (T) throws -> Loop) {
        onReceiveHandler = handler
    }
    
    // MARK: Process
    
    public func spawn() {
        ActorCenter.default.register(actor: self)
    }
    
    public class func spawn(block: @escaping (Actor<T>) -> Void) -> Actor<T> {
        let actor: Actor<T> = self.init()
        block(actor)
        actor.spawn()
        return actor
    }
    
    // MARK: Message passing
    
    public func send(message: T) {
        self.messageQueue.enqueue(message)
    }
    
    public func pop() -> T? {
        if let message = self.messageQueue.dequeue() {
            return message
        } else {
            return nil
        }
    }

    func evaluate(message: T) throws {
        if let handler = onReceiveHandler {
            switch try handler(message) {
            case .continue:
                break
            case .break:
                terminate()
            case .timeout:
                timeoutForced = true
            }
        }
    }
    
}

infix operator !

func !<T>(lhs: Actor<T>, rhs: T) {
    lhs.send(message: rhs)
}

class MessageQueue<T> {
    
    weak var actor: Actor<T>!
    var firstItem: MessageQueueItem<T>?
    var lastItem: MessageQueueItem<T>?
    var count: Int = 0
    
    private let lockQueue = DispatchQueue(label: "Message queue")
    
    init(actor: Actor<T>) {
        self.actor = actor
    }
    
    func enqueue(_ value: T) {
        lockQueue.sync {
            let item = MessageQueueItem(value: value)
            if count == 0 {
                firstItem = item
                lastItem = item
            } else {
                lastItem?.next = item
                lastItem = item
            }
            count += 1
        }
    }
    
    func dequeue() -> T? {
        var result: T?
        lockQueue.sync {
            if let item = firstItem {
                firstItem = item.next
                count -= 1
                if count == 0 {
                    firstItem = nil
                    lastItem = nil
                }
                result = item.value
            }
        }
        return result
    }
    
}

class MessageQueueItem<T> {
    
    var value: T
    var next: MessageQueueItem<T>?
    
    init(value: T) {
        self.value = value
    }
    
}
