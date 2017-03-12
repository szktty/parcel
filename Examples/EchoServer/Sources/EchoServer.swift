import Foundation
import Parcel

class EchoServer {
    
    var server: TCPServer
    var hostname: String
    var port: UInt16
    
    init(hostname: String, port: UInt16) throws {
        self.hostname = hostname
        self.port = port
        server = try TCPServer(hostname: hostname, port: port)
    }
    
    func run() throws {
        try server.run { p in
            p.onReceive { packet in
                // This client object will be released and
                // closed the connection automatically.
                // If you keep client connection, retain the client object.
                switch packet.state {
                case .bytes(let bytes):
                    if let s = String(bytes: bytes, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) {
                        print("received:", s)
                        switch s {
                        case "bye":
                            try packet.client.close()
                            return .break
                            
                        default:
                            let _ = try packet.client.send(bytes: s.toBytes())
                        }
                    }
                case .closed:
                    try packet.client.close()
                    return .break
                case .error(let error):
                    print("ERROR:", error.localizedDescription)
                    return .break
                }
                return .continue
            }
        }
    }
    
}
