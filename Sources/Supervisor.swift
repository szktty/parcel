import Foundation
import Result

public protocol SupervisorDelegate {
    
    func setUp()
    
}

public enum SupervisorRestart {

    case permanent
    case transient
    case temporary
    
}

public enum SupervisorShutdown {
    
    case brutalKill
    case timeout
    
}

public enum SupervisorWorker {
    
    case worker
    case supervisor
    
}

public enum SupervisorStrategy {
    
    case oneForAll
    case oneForOne
    case restForOne
    case simpleOneForOne
    
}

public class SupervisorFlags {
    
}

public class SupervisorChildSpecification<Message> {
    
    public var child: Parcel<Message>!
    public var restart: SupervisorRestart!
    
}

open class Supervisor {
    
    public var delegate: SupervisorDelegate?
    
}
    
