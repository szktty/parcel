import Foundation

class Worker {
    
    weak var scheduler: Scheduler!
    var workerId: Int
    var dispatchQueue: DispatchQueue
    var actors: [AnyObject] = []

    init(scheduler: Scheduler, workerId: Int) {
        self.scheduler = scheduler
        self.workerId = workerId
        dispatchQueue = DispatchQueue(label: workerId.description)
    }
    
    func register<T>(actor: Actor<T>) {
        dispatchQueue.async {
            actor.worker = self
            self.actors.append(actor)
            while !actor.isTerminate {
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
        // TODO: performance?
        actors = actors.filter {
            e in
            return ObjectIdentifier(e) != ObjectIdentifier(actor)
        }
    }
    
}
