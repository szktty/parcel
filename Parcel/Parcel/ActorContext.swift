import Foundation

public class ActorContext<T> {
    
    public var actor: Actor<T>!
    var mailbox: Mailbox<T>!
    weak var worker: Worker!
    var isTerminate: Bool = false

    init(actor: Actor<T>) {
        self.actor = actor
        actor.context = self
        mailbox = Mailbox(context: self)
    }
 
    public func terminate() {
        isTerminate = true
    }
    
    func send(_ message: T) {
        mailbox.add(message: message)
    }
    
    func receive(_ message: T) {
        actor.receive(message)
    }
    
}

infix operator !

func !<T>(lhs: ActorContext<T>, rhs: T) {
    lhs.send(rhs)
}

class Mailbox<T> {
    
    weak var context: ActorContext<T>!
    var messageQueue: MessageQueue<T> = MessageQueue()
    var locked: Bool = false
    
    public init(context: ActorContext<T>) {
        self.context = context
    }
    
    public func add(message: T) {
        lock {
            self.messageQueue.enqueue(message)
        }
    }
    
    public func pop() -> T? {
        return lock {
            if let message = self.messageQueue.dequeue() {
                return message
            } else {
                return nil
            }
        }
    }
    
    func lock<V>(block: () -> V?) -> V? {
        while locked {}
        locked = true
        let result = block()
        locked = false
        return result
    }
    
}

class MessageQueue<T> {

    var firstItem: MessageQueueItem<T>?
    var lastItem: MessageQueueItem<T>?
    var count: Int = 0
    
    private let lockQueue = DispatchQueue(label: "Message queue")
    
    func enqueue(_ value: T) {
        lockQueue.sync {
            let item = MessageQueueItem(value: value)
            if count == 0 {
                firstItem = item
                lastItem = item
            } else {
                lastItem?.next = item
                lastItem = item
            }
            count += 1
        }
    }
    
    func dequeue() -> T? {
        var result: T?
        lockQueue.sync {
            if let item = firstItem {
                firstItem = item.next
                count -= 1
                if count == 0 {
                    firstItem = nil
                    lastItem = nil
                }
                result = item.value
            }
        }
        return result
    }
    
}

class MessageQueueItem<T> {
    
    var value: T
    var next: MessageQueueItem<T>?
    
    init(value: T) {
        self.value = value
    }
    
}
