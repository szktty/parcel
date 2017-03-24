import Foundation

public enum Loop {
    case `continue`
    case `break`
}

public enum Signal {
    case normal
    case timeout
    case forced
    case error(Error)
}

open class BasicParcel {
    
    public var id: ObjectIdentifier {
        get { return ObjectIdentifier(self) }
    }
    
    public var isAvailable: Bool {
        get {
            return worker != nil && !isTerminated
        }
    }
    
    weak var worker: Worker!
    var isTerminated: Bool = false
    var onTerminateHandler: ((Signal) -> Void)?
    var onUpdateHandler: ((BasicParcel, Signal) -> Void)?

    // Do not use DispatchQueue.sync().
    // This dispatch queue is shared with other parcels managed by a same worker.
    var dispatchQueue: DispatchQueue {
        get { return worker.executeQueue }
    }
    
    // MARK: Terminating
    
    public func onTerminate(handler: @escaping (Signal) -> Void) {
        onTerminateHandler = handler
    }
    
    public func terminate(error: Error? = nil) {
        let signal: Signal = error != nil ? .error(error!) : .normal
        ParcelCenter.default.terminate(parcel: self, signal: signal)
    }
    
    public func terminateAfter(deadline: UInt,
                               error: Error? = nil,
                               execute: @escaping () -> Void) {
        let signal: Signal = error != nil ? .error(error!) : .normal
        worker.asyncAfter(parcel: self, deadline: deadline) {
            execute()
            ParcelCenter.default.terminate(parcel: self, signal: signal)
        }
    }
    
    // called from ParcelCenter
    func finishTerminating(signal: Signal) {
        onTerminateHandler?(signal)
        worker.unassign(parcel: self)
        isTerminated = true
    }
    
    // MARK: Dependents
    
    public func addLink(_ parcel: BasicParcel) {
        ParcelCenter.default.addEachOfObservers(parcel1: self,
                                                parcel2: parcel,
                                                relationship: .link)
    }
    
    public func addMonitor(_ observer: BasicParcel) {
        ParcelCenter.default.addObserver(observer,
                                         dependent: self,
                                         relationship: .monitor)
    }
    
    public func onUpdate(handler: @escaping (BasicParcel, Signal) -> Void) {
        onUpdateHandler = handler
    }
    
    func update(dependent: BasicParcel, signal: Signal) {
        onUpdateHandler?(dependent, signal)
    }
    
}

open class Parcel<Message>: BasicParcel {
    
    var onReceiveHandler: ((Message) throws -> Loop)?
    var mailbox: Mailbox<Message>!

    public required override init() {
        super.init()
        mailbox = Mailbox(parcel: self)
    }
    
    // MARK: Event handlers
    
    public func onReceive(handler: @escaping (Message) throws -> Loop) {
        onReceiveHandler = handler
    }
    
    // MARK: Running
    
    public func run() {
        ParcelCenter.default.addParcel(self)
    }
    
    public class func spawn(block: @escaping (Parcel<Message>) -> Void) -> Parcel<Message> {
        let parcel: Parcel<Message> = self.init()
        block(parcel)
        parcel.run()
        return parcel
    }
    
    // MARK: Message passing
    
    public func send(message: Message) {
        mailbox.enqueue(message)
    }
    
    // MARK: Mailbox
    
    public func pop() -> Message? {
        return mailbox.dequeue()
    }

    func evaluate(message: Message) throws {
        if let handler = onReceiveHandler {
            switch try handler(message) {
            case .continue:
                break
            case .break:
                terminate()
            }
        }
    }
    
}

infix operator !

public func !<Message>(lhs: Parcel<Message>, rhs: Message) {
    lhs.send(message: rhs)
}

class Mailbox<Message> {
    
    weak var parcel: Parcel<Message>!
    var firstItem: MailboxItem<Message>?
    var lastItem: MailboxItem<Message>?
    var count: Int = 0
    
    init(parcel: Parcel<Message>) {
        self.parcel = parcel
    }
    
    func enqueue(_ value: Message) {
        guard let worker = parcel.worker else { return }
        
        worker.mailboxQueue.sync {
            let item = MailboxItem(value: value)
            if count == 0 {
                firstItem = item
            } else {
                lastItem?.next = item
            }
            lastItem = item
            count += 1
        }
    }
    
    func dequeue() -> Message? {
        guard let worker = parcel.worker else { return nil }

        var result: Message?
        worker.mailboxQueue.sync {
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

class MailboxItem<Message> {
    
    var value: Message
    var next: MailboxItem<Message>?
    
    init(value: Message) {
        self.value = value
    }
    
}
