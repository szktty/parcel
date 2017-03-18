import Foundation

class Worker {
    
    var workerId: Int
    var messageQueue: DispatchQueue
    var executeQueue: DispatchQueue
    var lockQueue: DispatchQueue
    var mailboxQueue: DispatchQueue
    var parcels: [ObjectIdentifier: AnyObject] = [:]

    init(workerId: Int) {
        self.workerId = workerId
        self.messageQueue = DispatchQueue(label: workerId.description)
        self.executeQueue = DispatchQueue(label: "worker.execute")
        self.lockQueue = DispatchQueue(label: "worker.lock")
        self.mailboxQueue = DispatchQueue(label: "worker.mailbox")
    }
    
    func add<Message>(parcel: Parcel<Message>) {
        lockQueue.sync {
            parcel.worker = self
            self.parcels[ObjectIdentifier(parcel)] = parcel
        }
    }
    
    func remove<Message>(parcel: Parcel<Message>) {
        lockQueue.sync {
            parcel.worker = nil
            self.parcels[ObjectIdentifier(parcel)] = nil
        }
    }
    
    func register<Message>(parcel: Parcel<Message>) {
        self.add(parcel: parcel)

        messageQueue.async {
            while parcel.isAlive {
                guard let message = parcel.pop() else { continue }
                do {
                    try parcel.evaluate(message: message)
                } catch let error {
                    parcel.terminate(error: error)
                }
            }
            parcel.finish(signal: .normal)
            self.unregister(parcel: parcel)
        }
    }
    
    func unregister<Message>(parcel: Parcel<Message>) {
        remove(parcel: parcel)
    }
    
    // deadline: milliseconds
    func asyncAfter(parcel: BasicParcel,
                    deadline: UInt,
                    execute: @escaping () -> Void) {
        let deadline: DispatchTime = .now() + .milliseconds(Int(deadline))
        executeQueue.asyncAfter(deadline: deadline) {
            if parcel.isAlive {
                execute()
            }
        }
    }
    
}
