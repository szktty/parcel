import Foundation

public enum ParcelError: Error {
    case unspawned
    case death(BasicParcel)
    case user(Error)
}

public enum Loop {
    case `continue`
    case `break`
    case timeout
}

open class BasicParcel {
    
    public var id: ObjectIdentifier {
        get { return ObjectIdentifier(self) }
    }
    
    weak var worker: Worker?
    var deadline: DispatchTime?
    var timeoutHandler: (() -> Void)?
    var isAlive: Bool = true
    var timeoutForced: Bool = false
    var onErrorHandler: ((Error) -> Void)?
    var onDeathHandler: ((ParcelError) -> Void)?
    var onDownHandler: ((BasicParcel) -> Void)?

    public func after(deadline: DispatchTime, handler: @escaping () -> Void) {
        self.deadline = deadline
        timeoutHandler = handler
    }
    
    public func onError(handler: @escaping (Error) -> Void) {
        onErrorHandler = handler
    }
    
    public func onDeath(handler: @escaping (ParcelError) -> Void) {
        onDeathHandler = handler
    }
    
    public func onDown(handler: @escaping (BasicParcel) -> Void) {
        onDownHandler = handler
    }
    
    public func terminate() {
        isAlive = false
    }
    
    func handle(error: Error) {
        terminate()
        onErrorHandler?(error)
    }
    
}

open class Parcel<T>: BasicParcel {

    public var userInfo: [String: Any] = [:]
    
    var onReceiveHandler: ((T) throws -> Loop)?
    var messageQueue: MessageQueue<T>!

    public required override init() {
        super.init()
        messageQueue = MessageQueue(parcel: self)
    }
    
    // MARK: Event handlers
    
    public func onReceive(handler: @escaping (T) throws -> Loop) {
        onReceiveHandler = handler
    }
    
    // MARK: Process
    
    public func spawn() {
        ParcelCenter.default.register(parcel: self)
    }
    
    public class func spawn(block: @escaping (Parcel<T>) -> Void) -> Parcel<T> {
        let parcel: Parcel<T> = self.init()
        block(parcel)
        parcel.spawn()
        return parcel
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

func !<T>(lhs: Parcel<T>, rhs: T) {
    lhs.send(message: rhs)
}

class MessageQueue<T> {
    
    weak var parcel: Parcel<T>!
    var firstItem: MessageQueueItem<T>?
    var lastItem: MessageQueueItem<T>?
    var count: Int = 0
    
    private let lockQueue = DispatchQueue(label: "Message queue")
    
    init(parcel: Parcel<T>) {
        self.parcel = parcel
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
