import Foundation

// deprecated
public class OldParcelCenter {
    
    public var maxNumberOfWorkers: Int
    public var maxNumberOfParcels: Int
    
    var workers: [Worker]
    var parcelLinks: [ObjectIdentifier: [BasicParcel]] = [:]
    var parcelMonitors: [ObjectIdentifier: [BasicParcel]] = [:]
    var lockQueue: DispatchQueue
    
    var availableWorker: Worker {
        get {
            return workers.reduce(workers.first!) {
                min, worker in
                return worker.parcels.count < min.parcels.count ? worker : min
            }
        }
    }
    
    init(maxNumberOfWorkers: Int? = nil,
         maxNumberOfParcels: Int? = nil) {
        self.maxNumberOfWorkers = maxNumberOfWorkers ?? ProcessInfo.processInfo.processorCount
        self.maxNumberOfParcels = maxNumberOfParcels ?? 100000
        lockQueue = DispatchQueue(label: "parcel center")
        
        workers = []
        for i in 0..<self.maxNumberOfWorkers {
            workers.append(Worker(workerId: i))
        }
    }
    
    func register<Message>(parcel: Parcel<Message>) {
        availableWorker.register(parcel: parcel)
    }
    
    // MARK: Links
    
    public func addLink(parcel1: BasicParcel, parcel2: BasicParcel) {
        guard parcel1.id != parcel2.id else { return }
        lockQueue.sync {
            addOneLink(parcel1: parcel1, parcel2: parcel2)
            addOneLink(parcel1: parcel2, parcel2: parcel1)
        }
    }
    
    func addOneLink(parcel1: BasicParcel, parcel2: BasicParcel) {
        if var links = parcelLinks[parcel1.id] {
            for link in links {
                if link.id == parcel2.id {
                    return
                }
            }
            links.append(parcel2)
        } else {
            parcelLinks[parcel1.id] = [parcel2]
        }
    }
    
    public func removeLink(parcel1: BasicParcel, parcel2: BasicParcel) {
        guard parcel1.id != parcel2.id else { return }
        lockQueue.sync {
            removeOneLink(parcel1: parcel1, parcel2: parcel2)
            removeOneLink(parcel1: parcel2, parcel2: parcel1)
        }
    }
    
    func removeOneLink(parcel1: BasicParcel, parcel2: BasicParcel) {
        if var links = parcelLinks[parcel1.id] {
            let i = links.index {
                link in
                return link.id == parcel2.id
            }
            if let i = i {
                links.remove(at: i)
            }
        }
    }
    
    // MARK: Monitors
    
    public func addMonitor(_ monitor: BasicParcel,
                           forParcel target: BasicParcel) {
        guard monitor.id != target.id else { return }
        lockQueue.sync {
            if var monitors = parcelMonitors[target.id] {
                for other in monitors {
                    if other.id == monitor.id {
                        return
                    }
                }
                monitors.append(monitor)
            } else {
                parcelMonitors[target.id] = [monitor]
            }
        }
    }
    
    public func removeMonitor(_ monitor: BasicParcel,
                              forParcel target: BasicParcel) {
        guard monitor.id != target.id else { return }
        lockQueue.sync {
            if var monitors = parcelMonitors[target.id] {
                monitors = monitors.filter {
                    other in
                    return other.id != monitor.id
                }
                parcelMonitors[target.id] = monitors.isEmpty ? nil : monitors
            }
        }
    }
    
    // MARK: Terminate Parcels
    
    func terminate(parcel: BasicParcel, signal: Signal) {
        lockQueue.sync {
            parcel.finish(signal: signal)
            
            var terminated: [BasicParcel] = []
            terminateLinks(parcel: parcel, terminated: &terminated)
            terminateMonitors(parcel: parcel)
        }
    }
    
    func terminateLinks(parcel: BasicParcel, terminated: inout [BasicParcel]) {
        guard let links = parcelLinks[parcel.id] else { return }
        for link in links {
            if (terminated.contains { terminated in
                terminated.id == parcel.id
            }) {
                continue
            }
            terminated.append(link)
            link.finish(signal: .killed)
            terminateLinks(parcel: link, terminated: &terminated)
        }
        parcelLinks[parcel.id] = nil
    }
    
    func terminateMonitors(parcel: BasicParcel) {
        if let monitors = parcelMonitors[parcel.id] {
            for monitor in monitors {
                monitor.finish(signal: .down)
            }
            parcelMonitors[parcel.id] = nil
        }
    }
    
}

public class Dependency {
    
    enum Reason {
        
        case exit
        case down
        
    }
    
    public var diesTogether: Bool
    public var updatesObserver: Bool
    public var trapsDeath: Bool
    public var canStack: Bool
    
    public init(diesTogether: Bool = false,
                updatesObserver: Bool = false,
                trapsDeath: Bool = false,
                canStack: Bool = false) {
        self.diesTogether = diesTogether
        self.updatesObserver = updatesObserver
        self.trapsDeath = trapsDeath
        self.canStack = canStack
    }
    
    public static var link: Dependency = Dependency(diesTogether: true)
    public static var monitor: Dependency = Dependency(updatesObserver: true,
                                                       canStack: true)
    public static var trapper: Dependency = Dependency(trapsDeath: true,
                                                       canStack: true)
    
}

public class Dependent {
    
    public var parcel: BasicParcel
    public var dependency: Dependency
    
    public init(parcel: BasicParcel, dependency: Dependency) {
        self.parcel = parcel
        self.dependency = dependency
    }
    
}

public class ParcelCenter: OldParcelCenter {
    
    public static var `default`: ParcelCenter = ParcelCenter()
    
    var parcels: [ObjectIdentifier: BasicParcel] = [:]
    var parcelLockQueue: DispatchQueue
    var dependents: [ObjectIdentifier: [Dependent]] = [:]

    // MARK: Dependency
    
    init() {
        parcelLockQueue = DispatchQueue(label: "parcelLockQueue")
    }
    
    public func addObserver(_ observer: BasicParcel,
                            dependent: BasicParcel,
                            dependency: Dependency) {
        let dep = Dependent(parcel: dependent, dependency: dependency)
    }
    
    public func removeObserver(_ observer: BasicParcel,
                               dependent: BasicParcel? = nil,
                               dependency: Dependency? = nil) {
        
    }
    
    func removeParcel(_ parcel: BasicParcel, sync: Bool = true) {
        if sync {
            parcelLockQueue.sync {
                parcels[parcel.id] = nil
            }
        } else {
            parcels[parcel.id] = nil
        }
    }
    
    public func kill(parcel: BasicParcel) {
        
    }
    
    public func exit(parcel: BasicParcel) {
        
    }
    
    public func down(parcel: BasicParcel) {
        
    }
    
}
