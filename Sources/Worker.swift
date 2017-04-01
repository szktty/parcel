import Foundation

class Worker {
    
    var workerId: Int
    var numberOfParcels: Int = 0
    var mainQueue: DispatchQueue
    var messageQueue: DispatchQueue
    var mailbox: Mailbox!

    init(workerId: Int) {
        self.workerId = workerId
        self.mainQueue = DispatchQueue(label: "worker main")
        self.messageQueue = DispatchQueue(label: "message loop")
        mailbox = Mailbox(worker: self)
        
        messageQueue.async {
            while true {
                if let mail = self.mailbox.dequeue() {
                    if mail.parcel.isAvailable {
                        do {
                            try mail.handler()
                        } catch let error {
                            mail.parcel.terminate(error: error)
                        }
                    }
                }
            }
        }
    }
    
    func assign(parcel: BasicParcel) {
        parcel.worker = self
        numberOfParcels += 1
    }
    
    func unassign(parcel: BasicParcel) {
        parcel.worker = nil
        numberOfParcels -= 1
    }
    
}

class Mail {
    
    var parcel: BasicParcel
    var message: Any
    var handler: () throws -> Void
    
    init(parcel: BasicParcel, message: Any, handler: @escaping () throws -> Void) {
        self.parcel = parcel
        self.message = message
        self.handler = handler
    }
}

class MailboxItem {
    
    var mail: Mail
    var next: MailboxItem?
    
    init(mail: Mail) {
        self.mail = mail
    }
    
}

class Mailbox {
    
    var worker: Worker
    var firstItem: MailboxItem?
    var lastItem: MailboxItem?
    var count: Int = 0
    var lockQueue: DispatchQueue
    
    init(worker: Worker) {
        self.worker = worker
        lockQueue = DispatchQueue(label: "mailbox")
    }
    
    func enqueue(_ mail: Mail) {
        lockQueue.sync {
            let item = MailboxItem(mail: mail)
            if count == 0 {
                firstItem = item
            } else {
                lastItem?.next = item
            }
            lastItem = item
            count += 1
        }
    }
    
    func dequeue() -> Mail? {
        var result: Mail?
        lockQueue.sync {
            if let item = firstItem {
                firstItem = item.next
                count -= 1
                if firstItem == nil {
                    lastItem = nil
                }
                result = item.mail
            }
        }
        return result
    }
    
}
