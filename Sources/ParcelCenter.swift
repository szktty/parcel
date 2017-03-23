import Foundation

public enum AutoTermination {

    case normal
    case error
    case off
    
}

public class DependentRelationship {
    
    public var autoTermination: AutoTermination
    public var updatesObserver: Bool
    public var canStack: Bool
    
    public init(autoTermination: AutoTermination = .normal,
                updatesObserver: Bool = false,
                trapsDeath: Bool = false,
                canStack: Bool = false) {
        self.autoTermination = autoTermination
        self.updatesObserver = updatesObserver
        self.canStack = canStack
    }
    
    public static var link: DependentRelationship =
        DependentRelationship()
    public static var monitor: DependentRelationship =
        DependentRelationship(updatesObserver: true,
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
    var parcelStore: [ObjectIdentifier: BasicParcel] = [:]
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
    
    // MARK: Parcels
    
    func addParcel<Message>(_ parcel: Parcel<Message>) {
        parcelLockQueue.sync {
            parcelStore[parcel.id] = parcel
            availableWorker.assign(parcel: parcel)
        }
    }
    
    func removeParcel(_ parcel: BasicParcel) -> Bool {
        return parcelLockQueue.sync {
            if parcelStore[parcel.id] == nil {
                return false
            } else {
                parcelStore[parcel.id] = nil
                parcel.finishTerminating(signal: .down) // TODO
                return true
            }
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
        if !removeParcel(parcel) {
            return
        }
        
        if !ignoreDepenencies {
            // TODO: signal
            resolveDependencies(signal: .down, dependent: parcel)
        }
    }
    
    func resolveDependencies(signal: Signal, dependent: BasicParcel) {
        guard let depcies = depcyStore[dependent.id] else { return }

        parcelLockQueue.sync {
            depcyStore[dependent.id] = nil
        }
        
        for depcy in depcies {
            let rel = depcy.relationship
            
            switch rel.autoTermination {
            case .normal:
                terminate(parcel: depcy.observer, signal: signal)
                
            case .error:
                switch signal {
                case .normal:
                    break
                default:
                    terminate(parcel: depcy.observer, signal: signal)
                }
                
            case .off:
                break
            }

            if rel.updatesObserver {
                depcy.observer.update(dependent: dependent, signal: signal)
            }
        }
    }
    
}
