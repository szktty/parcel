import Foundation

class Worker {
    
    var workerId: Int
    var dispatchQueue: DispatchQueue
    var lockQueue: DispatchQueue
    var parcels: [ObjectIdentifier: AnyObject] = [:]

    init(workerId: Int,
         dispatchQueue: DispatchQueue? = nil) {
        self.workerId = workerId
        self.dispatchQueue = dispatchQueue
            ?? DispatchQueue(label: workerId.description)
        self.lockQueue = DispatchQueue(label: "parcels")
    }
    
    func add<T>(parcel: Parcel<T>) {
        lockQueue.sync {
            parcel.worker = self
            self.parcels[ObjectIdentifier(parcel)] = parcel
        }
    }
    
    func remove<T>(parcel: Parcel<T>) {
        lockQueue.sync {
            parcel.worker = nil
            self.parcels[ObjectIdentifier(parcel)] = nil
        }
    }
    
    func register<T>(parcel: Parcel<T>) {
        self.add(parcel: parcel)

        if let deadline = parcel.deadline {
            self.dispatchQueue.asyncAfter(deadline: deadline) {
                if parcel.isAlive || parcel.timeoutForced {
                    parcel.timeoutHandler?()
                    self.unregister(parcel: parcel)
                }
            }
        }
        
        dispatchQueue.async {
            while parcel.isAlive {
                guard let message = parcel.pop() else { continue }
                do {
                    try parcel.evaluate(message: message)
                } catch let error {
                    parcel.exit(error: error)
                }
            }
            parcel.finish(signal: .normal)
            self.unregister(parcel: parcel)
        }
    }
    
    func unregister<T>(parcel: Parcel<T>) {
        remove(parcel: parcel)
    }
    
}
