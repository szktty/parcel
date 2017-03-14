# Parcel

Actor-based concurrency library for Swift (experimental)

## Usage

- Parcel<T>, ParcelCenter
- Parcel = Process (avoid ``Foundation.Process``)
- spawn
- message, <T>
- receive
- link
- monitor
- exit
- timer

## Examples

### Simple

Code:

```
import Parcel

// message definition
enum Area {
    case rectangle(Int, Int)
    case circle(Float)
    case exit
}

// create a process
let parcel = Parcel<Area>.spawn {
    parcel in

    // set callback when the parcel receives a new message
    parcel.onReceive {
        message in
        switch message {
        case .rectangle(let width, let height):
            print("Area of rectangle is \(width), \(height)")
        case .circle(let r):
            let circle = 3.14159 * r * r
            print("Area of circle is \(circle)")
        case .exit:
            print("Exit")
            // terminate the process
            return .break
        }

        // wait next message
        return .continue
    }
}

// message passing
parcel ! .rectangle(6, 10)
parcel ! .circle(23)
parcel ! .exit
```

Output:

```
Area of rectangle is 6, 10
Area of circle is 1661.9
Exit
```

### Echo Server

```
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
```
