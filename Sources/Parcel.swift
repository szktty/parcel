import Foundation

public enum Loop {
    case `continue`
    case `break`
}

public enum Signal {
    case normal
    case timeout
    case kill
    case killed
    case down
    case error(Error)
}

open class BasicParcel {
    
    public var isAlive: Bool = true

    public var id: ObjectIdentifier {
        get { return ObjectIdentifier(self) }
    }
    
    weak var worker: Worker!
    var onTerminateHandler: ((Signal) -> Void)?

    // MARK: Executing Work Items
    
    public func sync(execute: () -> Void) {
        worker.executeQueue.sync(execute: execute)
    }
    
    public func async(execute: @escaping () -> Void) {
        worker.executeQueue.async(execute: execute)
    }
    
    // deadline: milliseconds
    public func asyncAfter(deadline: UInt, execute: @escaping () -> Void) {
        worker.asyncAfter(parcel: self, deadline: deadline, execute: execute)
    }
    
    // MARK: Terminating
    
    public func onTerminate(handler: @escaping (Signal) -> Void) {
        onTerminateHandler = handler
    }
    
    public func terminate(error: Error? = nil) {
        let signal: Signal = error != nil ? .error(error!) : .normal
        ParcelCenter.default.terminate(parcel: self, signal: signal)
    }

    public func terminateAfter(deadline: UInt, execute: @escaping () -> Void) {
        asyncAfter(deadline: deadline) {
            ParcelCenter.default.terminate(parcel: self, signal: .timeout)
            execute()
        }
    }
    
    func finish(signal: Signal) {
        isAlive = false
        onTerminateHandler?(signal)
    }
    
}

open class Parcel<T>: BasicParcel {
    
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
    
    // MARK: Running
    
    public func run() {
        ParcelCenter.default.register(parcel: self)
    }
    
    public class func spawn(block: @escaping (Parcel<T>) -> Void) -> Parcel<T> {
        let parcel: Parcel<T> = self.init()
        block(parcel)
        parcel.run()
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
                terminate()
            }
        }
    }

    public func addLink(_ parcel: Parcel<T>) {
        ParcelCenter.default.addLink(parcel1: self, parcel2: parcel)
    }
    
    public func addMonitor(_ parcel: Parcel<T>) {
        ParcelCenter.default.addMonitor(parcel, forParcel: self)
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
