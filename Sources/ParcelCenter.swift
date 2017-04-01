import Foundation

public class DependentRelationship {
    
    public var terminatesAbnormally: Bool
    public var updatesObserver: Bool
    public var canStack: Bool
    
    public init(terminatesAbnormally: Bool = true,
                updatesObserver: Bool = false,
                trapsDeath: Bool = false,
                canStack: Bool = false) {
        self.terminatesAbnormally = terminatesAbnormally
        self.updatesObserver = updatesObserver
        self.canStack = canStack
    }
    
    public static var link: DependentRelationship =
        DependentRelationship()
    public static var monitor: DependentRelationship =
        DependentRelationship(terminatesAbnormally: false,
                              updatesObserver: true,
                              canStack: true)
    public static var trapper: DependentRelationship =
        DependentRelationship(trapsDeath: true,
                              canStack: true)
    
}

public class Dependency {
    
    public weak var observer: BasicParcel!
    public weak var dependent: BasicParcel!
    public var relationship: DependentRelationship
    
    public init(observer: BasicParcel,
                dependent: BasicParcel,
                relationship: DependentRelationship) {
        self.observer = observer
        self.dependent = dependent
        self.relationship = relationship
    }
    
}

public class ParcelCenter {
    
    public static var `default`: ParcelCenter = ParcelCenter()
    
    public var maxNumberOfWorkers: Int
    public var maxNumberOfParcels: Int
    
    var workers: [Worker]
    var parcelLockQueue: DispatchQueue
    var depcyStore: [ObjectIdentifier: [Dependency]] = [:]
    
    var availableWorker: Worker {
        get {
            return workers.reduce(workers.first!) {
                min, worker in
                return worker.numberOfParcels < min.numberOfParcels ? worker : min
            }
        }
    }
    
    init(maxNumberOfWorkers: Int? = nil,
         maxNumberOfParcels: Int? = nil) {
        self.maxNumberOfWorkers = maxNumberOfWorkers ?? ProcessInfo.processInfo.processorCount
        self.maxNumberOfParcels = maxNumberOfParcels ?? 100000
        parcelLockQueue = DispatchQueue(label: "parcelLockQueue")
        
        workers = []
        for i in 0..<self.maxNumberOfWorkers {
            workers.append(Worker(workerId: i))
        }
    }
    
    // MARK: Managing Parcels
    
    func initializeParcel<Message>(_ parcel: Parcel<Message>) {
        availableWorker.assign(parcel: parcel)
    }
    
    func finishParcel(_ parcel: BasicParcel, signal: Signal = .normal) -> Bool {
        if parcel.isAvailable {
            parcel.finishTerminating(signal: signal)
            return true
        } else {
            return false
        }
    }
    
    // MARK: Dependencies
    
    public func addObserver(_ observer: BasicParcel,
                            dependent: BasicParcel,
                            relationship: DependentRelationship) {
        parcelLockQueue.sync {
            let depcy = Dependency(observer: observer,
                                   dependent: dependent,
                                   relationship: relationship)
            if var depcies = depcyStore[dependent.id] {
                depcies.append(depcy)
                depcyStore[dependent.id] = depcies
            } else {
                depcyStore[dependent.id] = [depcy]
            }
        }
    }
    
    public func addEachOfObservers(parcel1: BasicParcel,
                                   parcel2: BasicParcel,
                                   relationship: DependentRelationship) {
        addObserver(parcel1, dependent: parcel2, relationship: relationship)
        addObserver(parcel2, dependent: parcel1, relationship: relationship)
    }
    
    public func removeObserver(_ observer: BasicParcel,
                               dependent: BasicParcel? = nil,
                               dependency: DependentRelationship? = nil) {
        // TODO
        parcelLockQueue.sync {
        }
    }
    
    func terminate(parcel: BasicParcel, signal: Signal, ignoreDepenencies: Bool = false) {
        if !finishParcel(parcel, signal: signal) {
            return
        }
        
        if !ignoreDepenencies {
            // TODO: signal
            resolveDependencies(signal: signal, dependent: parcel)
        }
    }
    
    func resolveDependencies(signal: Signal, dependent: BasicParcel) {
        guard let depcies = depcyStore[dependent.id] else { return }

        parcelLockQueue.sync {
            depcyStore[dependent.id] = nil
        }
        
        for depcy in depcies {
            let rel = depcy.relationship
            if rel.terminatesAbnormally {
                terminate(parcel: depcy.observer, signal: signal)
            }
            if rel.updatesObserver {
                depcy.observer.update(dependent: dependent, signal: signal)
            }
        }
    }
    
}
