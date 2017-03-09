import Foundation

class Worker {
    
    var workerId: Int
    var dispatchQueue: DispatchQueue
    var lockQueue: DispatchQueue
    var actors: [ObjectIdentifier: AnyObject] = [:]

    init(workerId: Int,
         dispatchQueue: DispatchQueue? = nil) {
        self.workerId = workerId
        self.dispatchQueue = dispatchQueue
            ?? DispatchQueue(label: workerId.description)
        self.lockQueue = DispatchQueue(label: "actors")
    }
    
    func add<T>(actor: Actor<T>) {
        lockQueue.sync {
            actor.worker = self
            self.actors[ObjectIdentifier(actor)] = actor
        }
    }
    
    func remove<T>(actor: Actor<T>) {
        lockQueue.sync {
            actor.worker = nil
            self.actors[ObjectIdentifier(actor)] = nil
        }
    }
    
    func register<T>(actor: Actor<T>) {
        self.add(actor: actor)

        if let deadline = actor.deadline {
            self.dispatchQueue.asyncAfter(deadline: deadline) {
                if actor.isAlive || actor.timeoutForced {
                    actor.timeoutHandler?()
                    self.unregister(actor: actor)
                }
            }
        }
        
        dispatchQueue.async {
            while actor.isAlive {
                guard let message = actor.pop() else { continue }
                do {
                    try actor.evaluate(message: message)
                } catch {
                    break
                }
            }
            self.unregister(actor: actor)
        }
    }
    
    func unregister<T>(actor: Actor<T>) {
        actor.terminate()
        remove(actor: actor)
    }
    
}
