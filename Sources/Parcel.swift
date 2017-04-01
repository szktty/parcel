import Foundation

public enum Loop {
    case `continue`
    case `break`
}

public enum Signal: Error {
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
    
    // MARK: Terminating
    
    public func onTerminate(handler: @escaping (Signal) -> Void) {
        onTerminateHandler = handler
    }
    
    public func terminate(error: Error? = nil) {
        let signal: Signal = error != nil ? .error(error!) : .normal
        ParcelCenter.default.terminate(parcel: self, signal: signal)
    }
    
    public func terminateAfter(deadline: DispatchTimeInterval,
                               error: Error? = nil,
                               execute: @escaping () -> Void) {
        let signal: Signal = error != nil ? .error(error!) : .normal
        worker.mainQueue.asyncAfter(deadline: DispatchTime.now() + deadline) {
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

public final class Parcel<Message>: BasicParcel {
    
    var onReceiveHandler: ((Message) throws -> Loop)?

    public required override init() {
        super.init()
    }
    
    // MARK: Event handlers
    
    public func onReceive(handler: @escaping (Message) throws -> Loop) {
        onReceiveHandler = handler
    }
    
    // MARK: Running
    
    public func run() {
        ParcelCenter.default.initializeParcel(self)
    }
    
    public class func spawn(block: @escaping (Parcel<Message>) -> Void) -> Parcel<Message> {
        let parcel: Parcel<Message> = self.init()
        block(parcel)
        parcel.run()
        return parcel
    }
    
    // MARK: Message passing
    
    public func async(message: Message) {
        let mail = Mail(parcel: self, message: message) {
            try self.evaluate(message: message)
        }
        worker.mailbox.enqueue(mail)
    }

    private func evaluate(message: Message) throws {
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

// MARK: - Operators

infix operator !

public func !<Message>(lhs: Parcel<Message>, rhs: Message) {
    lhs.async(message: rhs)
}
