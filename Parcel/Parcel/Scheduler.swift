import Foundation

class Scheduler {
    
    static var `default`: Scheduler = Scheduler()
    
    var workers: [Worker]

    public var numberOfMaxProcesses: Int
    
    init(numberOfWorkers: Int? = nil,
         numberOfMaxProcesses: Int? = nil) {
        let numberOfWorkers = numberOfWorkers ?? ProcessInfo.processInfo.processorCount
        self.numberOfMaxProcesses = numberOfMaxProcesses ?? 100000
        
        workers = []
        for i in 0..<numberOfWorkers {
            workers.append(Worker(scheduler: self, workerId: i))
        }
    }
    
    func add<T>(actor: Actor<T>) {
        let context = ActorContext(actor: actor)
        assignWorker(context)
    }
    
    func assignWorker<T>(_ context: ActorContext<T>) {
        let worker = workers.reduce(workers.first!) {
            min, worker in
            return worker.contexts.count < min.contexts.count ? worker : min
        }
        worker.add(context: context)
    }

}
