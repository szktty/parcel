import Foundation

public class ParcelCenter {
    
    public static var `default`: ParcelCenter = ParcelCenter()
    public var maxNumberOfWorkers: Int
    public var maxNumberOfParcels: Int
    
    var workers: [Worker]
    var parcelLinks: [ObjectIdentifier: [BasicParcel]] = [:]
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
    
    public func link(parcel1: BasicParcel, parcel2: BasicParcel) {
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
    
    func dead(parcel: BasicParcel, cause: BasicParcel? = nil) {
        let item = DispatchWorkItem {
            if let links = self.parcelLinks[parcel.id] {
                for link in links {
                    if link.id == cause?.id {
                        continue
                    }
                    link.onDeathHandler?(.death(parcel))
                    self.dead(parcel: link, cause: parcel)
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
    
}
