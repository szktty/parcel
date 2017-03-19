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
    
    // MARK: Timer
    
    public func waitForStop(timeout: UInt,
                            execute: @escaping (ParcelTimer) throws -> Void) throws {
        try ParcelTimer(parcel: self).wait(timeout: timeout, execute: execute)
    }
    
}

public class ParcelTimer {
    
    public enum Error: Swift.Error {
        
        case timeout
        
    }
    
    weak var parcel: BasicParcel!
    var waitQueue: DispatchQueue
    var complete: Bool = false
    
    init(parcel: BasicParcel) {
        self.parcel = parcel
        waitQueue = DispatchQueue(label: "ParcelTimer")
    }
    
    func wait(timeout: UInt, execute: @escaping (ParcelTimer) throws -> Void) throws {
        var error: Swift.Error?
        let deadline: DispatchTime = .now() + .milliseconds(Int(timeout))
        waitQueue.asyncAfter(deadline: deadline) {
            if !self.complete {
                error = Error.timeout
                self.complete = true
            }
        }
        
        waitQueue.async {
            do {
                try execute(self)
            } catch let e {
                error = e
            }
        }
        while !complete {}
        if let error = error {
            throw error
        }
    }
    
    public func stop() {
        complete = true
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
        ParcelCenter.default.register(parcel: self)
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

    public func addLink(_ parcel: Parcel<Message>) {
        ParcelCenter.default.addLink(parcel1: self, parcel2: parcel)
    }
    
    public func addMonitor(_ parcel: Parcel<Message>) {
        ParcelCenter.default.addMonitor(parcel, forParcel: self)
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
        parcel.worker.mailboxQueue.sync {
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
        var result: Message?
        parcel.worker.mailboxQueue.sync {
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
