import Foundation

class Worker {
    
    var workerId: Int
    var numberOfParcels: Int = 0
    var messageQueue: DispatchQueue
    var executeQueue: DispatchQueue
    var mailboxQueue: DispatchQueue

    init(workerId: Int) {
        self.workerId = workerId
        self.messageQueue = DispatchQueue(label: workerId.description)
        self.executeQueue = DispatchQueue(label: "worker.execute")
        self.mailboxQueue = DispatchQueue(label: "worker.mailbox")
    }
    
    func assign<Message>(parcel: Parcel<Message>) {
        executeQueue.sync {
            parcel.worker = self
            numberOfParcels += 1
        }
        messageQueue.async {
            // TODO: error handling
            while parcel.isAlive {
                guard let message = parcel.pop() else { continue }
                do {
                    try parcel.evaluate(message: message)
                } catch let error {
                    parcel.terminate(error: error)
                }
            }
            let _ = ParcelCenter.default.removeParcel(parcel)
        }
    }
    
    func unassign(parcel: BasicParcel) {
        executeQueue.sync {
            parcel.worker = nil
            numberOfParcels -= 1
        }
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
