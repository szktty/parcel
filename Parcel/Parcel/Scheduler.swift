import Foundation

public class Scheduler {
    
    public static var `default`: Scheduler = Scheduler()
    public var numberOfMaxProcesses: Int
    
    var workers: [Worker]

    var availableWorker: Worker {
        get {
            return workers.reduce(workers.first!) {
                min, worker in
                return worker.actors.count < min.actors.count ? worker : min
            }
        }
    }
    
    init(numberOfWorkers: Int? = nil,
         numberOfMaxProcesses: Int? = nil) {
        let numberOfWorkers = numberOfWorkers ?? ProcessInfo.processInfo.processorCount
        self.numberOfMaxProcesses = numberOfMaxProcesses ?? 100000
        
        workers = []
        for i in 0..<numberOfWorkers {
            workers.append(Worker(scheduler: self, workerId: i))
        }
    }
    
    func register<T>(actor: Actor<T>) {
        availableWorker.register(actor: actor)
    }

}
