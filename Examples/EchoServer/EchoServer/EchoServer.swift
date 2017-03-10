import Foundation
import SwiftSocket
import Parcel

class EchoServer {
    
    var server: ParcelTCPServer
    var serverParcel: Parcel<Void>?
    var address: String
    var port: Int32
    
    init(address: String, port: Int32) {
        server = ParcelTCPServer(address: address, port: port)
        self.address = address
        self.port = port
    }
    
    func run() {
        serverParcel = Parcel<Void>.spawn {
            p in
            switch self.server.listen() {
            case .failure(let error):
                print(error)
                p.terminate()
                
            case .success:
                print("run server at \(self.address):\(self.port)")
                self.server.accept(self.loop())
            }
        }
    }
    
    func loop() -> Parcel<(TCPClient, [Byte]?)> {
        return Parcel<(TCPClient, [Byte]?)>.spawn {
            p in
            p.onReceive {
                (client, data) in
                if let data = data {
                    if let s = String(bytes: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) {
                        switch s {
                        case "bye":
                            print("bye!")
                            client.close()
                            return .break
                            
                        default:
                            let _ = client.send(string: "ECHO: " + s)
                        }
                    }
                }
                return .continue
            }
        }
    }
    
}

class ParcelTCPServer {
    
    var server: TCPServer
    
    init(address: String, port: Int32) {
        server = TCPServer(address: address, port: port)
    }
    
    func listen() -> Result {
        return server.listen()
    }
    
    func accept(_ parcel: Parcel<(TCPClient, [Byte]?)>) {
        let _ = Parcel<Void>.spawn {
            p in
            ParcelCenter.default.addLink(parcel1: p, parcel2: parcel)
            while true {
                if let client = self.server.accept() {
                    print("connect from \(client.address)[\(client.port)]")
                    while true {
                        let data = client.read(1024 * 10)
                        parcel.send(message: (client, data))
                    }
                }
            }
        }
    }
    
}
