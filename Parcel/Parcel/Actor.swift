import Foundation

public enum ActorError: Error {
    case unspawned
}

public enum Loop {
    case `continue`
    case `break`
    case timeout
}

public class Actor<T> {

    public weak var scheduler: Scheduler?
    public var userInfo: [String: Any] = [:]
    
    weak var worker: Worker?
    var messageHandler: ((T) throws -> Loop)?
    var deadline: DispatchTime?
    var timeoutHandler: (() -> Void)?
    var isTerminate: Bool = false
    var errorHandler: ((Error) -> Void)?
    var messageQueue: MessageQueue<T>!

    public required init(scheduler: Scheduler? = nil) {
        self.scheduler = scheduler ?? Scheduler.default
        messageQueue = MessageQueue(actor: self)
    }
    
    // MARK: Event handlers
    
    public func receive(handler: @escaping (T) throws -> Loop) {
        messageHandler = handler
    }
    
    public func after(deadline: DispatchTime, handler: @escaping () -> Void) {
        self.deadline = deadline
        timeoutHandler = handler
    }
    
    public func rescue(handler: @escaping (Error) -> Void) {
        errorHandler = handler
    }
    
    // MARK: Process
    
    public func spawn(scheduler: Scheduler? = nil) {
        let scheduler = scheduler ?? Scheduler.default
        scheduler.register(actor: self)
    }
    
    public class func spawn(scheduler: Scheduler? = nil,
                            block: @escaping (Actor<T>) -> Void) -> Actor<T> {
        let actor: Actor<T> = self.init(scheduler: scheduler)
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
        if let handler = messageHandler {
            switch try handler(message) {
            case .continue:
                break
            case .break:
                terminate()
            case .timeout:
                // TODO
                break
            }
        }
    }
    
    public func terminate() {
        isTerminate = true
    }
    
    func handle(error: Error) {
        terminate()
        errorHandler?(error)
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
