import Foundation

public class ActorCenter {
    
    public static var `default`: ActorCenter = ActorCenter()
    public var maxNumberOfWorkers: Int
    public var maxNumberOfActors: Int
    
    var workers: [Worker]
    var actorLinks: [ObjectIdentifier: [BasicActor]] = [:]
    var lockQueue: DispatchQueue

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
        lockQueue = DispatchQueue(label: "actor center")
        
        workers = []
        for i in 0..<self.maxNumberOfWorkers {
            workers.append(Worker(workerId: i))
        }
    }
    
    func register<T>(actor: Actor<T>) {
        availableWorker.register(actor: actor)
    }
    
    public func link(actor1: BasicActor, actor2: BasicActor) {
        guard actor1.id != actor2.id else { return }
        lockQueue.sync {
            if var links = actorLinks[actor1.id] {
                for link in links {
                    if link.id == actor2.id {
                        return
                    }
                }
                links.append(actor2)
            } else {
                actorLinks[actor1.id] = [actor2]
            }
        }
    }
    
    func dead(actor: BasicActor, cause: BasicActor? = nil) {
        let item = DispatchWorkItem {
            if let links = self.actorLinks[actor.id] {
                for link in links {
                    if link.id == cause?.id {
                        continue
                    }
                    link.onDeathHandler?(.death(actor))
                    self.dead(actor: link, cause: actor)
                }
                self.actorLinks[actor.id] = nil
            }
        }
        
        if cause != nil {
            // avoid recursive call and deadlock
            item.perform()
        } else {
            lockQueue.sync(execute: item)
        }
    }
    
}
