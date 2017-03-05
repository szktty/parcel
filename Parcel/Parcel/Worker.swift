import Foundation

class Worker {
    
    weak var scheduler: Scheduler!
    var workerId: Int
    var dispatchQueue: DispatchQueue
    var contexts: [AnyObject] = []

    init(scheduler: Scheduler, workerId: Int) {
        self.scheduler = scheduler
        self.workerId = workerId
        dispatchQueue = DispatchQueue(label: workerId.description)
    }
    
    func add<T>(context: ActorContext<T>) {
        dispatchQueue.async {
            self.contexts.append(context)
            while !context.isTerminate {
                if let message = context.mailbox.pop() {
                    context.receive(message)
                }
            }
            self.remove(context: context)
        }
    }
    
    func remove<T>(context: ActorContext<T>) {
        contexts = contexts.filter {
            e in
            return ObjectIdentifier(e) != ObjectIdentifier(context)
        }
    }
    
}
