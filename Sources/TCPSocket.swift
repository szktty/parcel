import Foundation
import SocksCore

public struct TCPPacket {
    
    public let client: TCPClient
    public let state: TCPState
    
}

public enum TCPState {
    
    case bytes([UInt8])
    case closed
    case error(Error)
    
}

public class TCPClient {
    
    public let hostname: String
    public let port: UInt16
    public var queueLimit: Int32 = 4096
    
    var socket: TCPInternetSocket?
    
    public init(hostname: String, port: UInt16,
                socket: TCPInternetSocket? = nil) {
        self.hostname = hostname
        self.port = port
        self.socket = socket
    }
    
    public func connect() throws {
        try socket?.connect()
    }
    
    public func close() throws {
        try socket?.close()
    }
    
    public func send(bytes: [UInt8]) throws {
        try socket?.send(data: bytes)
    }
    
}

public class TCPServer {
    
    public let hostname: String
    public let port: UInt16
    public var queueLimit: Int32 = 4096

    var server: TCPInternetSocket!
    var parcel: Parcel<TCPPacket>!
    
    public init(hostname: String, port: UInt16) throws {
        self.hostname = hostname
        self.port = port
    }
    
    public func close() throws {
        try server.close()
        let client = TCPClient(hostname: hostname, port: port)
        parcel ! TCPPacket(client: client, state: .closed)
    }
    
    public func run(block: @escaping (Parcel<TCPPacket>) -> Void) throws -> Never {
        parcel = Parcel<TCPPacket>.spawn(block: block)
        try run(parcel: parcel)
    }
    
    public func run(parcel: Parcel<TCPPacket>) throws -> Never {
        self.parcel = parcel
        let address = InternetAddress(hostname: hostname, port: port)
        server = try TCPInternetSocket(address: address)
        try server.bind()
        try server.listen(queueLimit: queueLimit)
        
        while true {
            do {
                let socket = try server.accept()
                let client = TCPClient(hostname: hostname, port: port, socket: socket)
                let state = TCPState.bytes(try socket.recvAll())
                parcel ! TCPPacket(client: client, state: state)
            } catch let error {
                let client = TCPClient(hostname: hostname, port: port)
                parcel ! TCPPacket(client: client, state: .error(error))
            }
            
        }
    }
    
}
