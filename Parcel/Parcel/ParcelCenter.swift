import Foundation

public class ParcelCenter {
    
    public static var `default`: ParcelCenter = ParcelCenter()
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
    
    func register<T>(parcel: Parcel<T>) {
        availableWorker.register(parcel: parcel)
    }
    
    // MARK: Links
    
    public func addLink(parcel1: BasicParcel, parcel2: BasicParcel) {
        guard parcel1.id != parcel2.id else { return }
        lockQueue.sync {
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
    }
    
    // MARK: Monitors
    
    public func addMonitor(_ monitor: BasicParcel,
                           forParcel target: BasicParcel) {
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
    
    // MARK: Kill parcels
    
    func kill(parcel: BasicParcel, cause: BasicParcel? = nil) {
        killLinks(parcel: parcel, cause: cause)
        notifyMonitors(parcel: parcel)
    }
    
    // TODO: remove killed parcels
    func killLinks(parcel: BasicParcel, cause: BasicParcel? = nil) {
        let item = DispatchWorkItem {
            if let links = self.parcelLinks[parcel.id] {
                for link in links {
                    if link.id == cause?.id {
                        continue
                    }
                    link.onDeathHandler?(.death(parcel))
                    self.killLinks(parcel: link, cause: parcel)
                }
                self.parcelLinks[parcel.id] = nil
            }
        }
        
        if cause != nil {
            // avoid recursive call and deadlock
            item.perform()
        } else {
            lockQueue.sync(execute: item)
        }
    }
    
    func notifyMonitors(parcel: BasicParcel) {
        lockQueue.sync {
            if let monitors = parcelMonitors[parcel.id] {
                for monitor in monitors {
                    monitor.onDownHandler?(parcel)
                }
                parcelMonitors[parcel.id] = nil
            }
        }
    }
    
}
