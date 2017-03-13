import Foundation

public enum Loop {
    case `continue`
    case `break`
    case timeout
}

public enum Signal {
    case normal
    case kill
    case killed
    case down
    case error(Error)
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
    var onExitHandler: ((Signal) -> Void)?

    public func after(deadline: DispatchTime, handler: @escaping () -> Void) {
        self.deadline = deadline
        timeoutHandler = handler
    }
    
    public func onExit(handler: @escaping (Signal) -> Void) {
        onExitHandler = handler
    }
    
    public func exit(error: Error? = nil) {
        ParcelCenter.default.exit(parcel: self, error: error)
    }

    func finish(signal: Signal) {
        isAlive = false
        onExitHandler?(signal)
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
        messageQueue.enqueue(message)
    }
    
    public func pop() -> T? {
        return messageQueue.dequeue()
    }

    func evaluate(message: T) throws {
        if let handler = onReceiveHandler {
            switch try handler(message) {
            case .continue:
                break
            case .break:
                exit()
            case .timeout:
                timeoutForced = true
            }
        }
    }

}

infix operator !

public func !<T>(lhs: Parcel<T>, rhs: T) {
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
            } else {
                lastItem?.next = item
            }
            lastItem = item
            count += 1
        }
    }
    
    func dequeue() -> T? {
        var result: T?
        lockQueue.sync {
            if let item = firstItem {
                firstItem = item.next
                count -= 1
                if firstItem == nil {
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
