import Foundation

public enum TCPMessage {
    
    case data(client: TCPClient, data: Data)
    case closed(client: TCPClient)
    case error(client: TCPClient, error: Error)
    
}

open class TCPClient {
    
    var parcel: Parcel<TCPMessage>
    
    public static func connect() -> TCPClient? {
        return nil
    }
    
    public init(parcel: Parcel<TCPMessage>) {
        self.parcel = parcel
    }
    
    public func connect() {
    }
    
    public func close() {
        
    }
    
    public func send(data: Data) {
        
    }
    
}

open class TCPServer {
    
    public enum Option {
        case backlog(Int32)
    }
    
    public var address: String
    public var port: Int32
    public var options: [Option]
    public var socketDescriptor: Int32?
    
    public init(address: String, port: Int32, options: [Option] = []) {
        self.address = address
        self.port = port
        self.options = options
    }
    
    public func close() {
        if let sd = socketDescriptor {
            // 0, -1, errno
            Foundation.close(sd)
        }
    }
    
    public func listen() {
        socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        sockaddr_in(sin_len: UInt8(sizeof(sockaddr_in)),
                    sin_family: sa_family_t, sin_port: <#T##in_port_t#>, sin_addr: <#T##in_addr#>, sin_zero: <#T##(Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)#>)
        socklen_t(bigEndian: <#T##UInt32#>)

        bind(<#T##Int32#>, <#T##UnsafePointer<sockaddr>!#>, <#T##socklen_t#>)
        
        var backlog: Int32 = 5
        for option in options {
            switch option {
            case .backlog(let value):
                backlog = value
            default:
                break
            }
        }
        // TODO: error
        Foundation.listen(socketDescriptor!, backlog)
    }
    
    public func accept() {
        
    }
    
    public func receive() {
        
    }
    
}
*/
