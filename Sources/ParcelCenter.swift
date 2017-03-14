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
    
    func terminate(parcel: BasicParcel, error: Error?) {
        lockQueue.sync {
            let signal: Signal = error != nil ? .error(error!) : .normal
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
