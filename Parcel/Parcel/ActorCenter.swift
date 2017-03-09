import Foundation

public class ActorCenter {
    
    public static var `default`: ActorCenter = ActorCenter()
    public var maxNumberOfWorkers: Int
    public var maxNumberOfActors: Int
    
    var workers: [Worker]

    var availableWorker: Worker {
        get {
            return workers.reduce(workers.first!) {
                min, worker in
                return worker.actors.count < min.actors.count ? worker : min
            }
        }
    }
    
    init(maxNumberOfWorkers: Int? = nil,
         maxNumberOfActors: Int? = nil) {
        self.maxNumberOfWorkers = maxNumberOfWorkers ?? ProcessInfo.processInfo.processorCount
        self.maxNumberOfActors = maxNumberOfActors ?? 100000
        
        workers = []
        for i in 0..<self.maxNumberOfWorkers {
            workers.append(Worker(workerId: i))
        }
    }
    
    func register<T>(actor: Actor<T>) {
        availableWorker.register(actor: actor)
    }

}
