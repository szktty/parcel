# Parcel

Parcel is an Erlang-like actor-based concurrency library for Swift (experimental).

## Usage

A main component of this library is actor reperesented as ``Parcel`` objects.
``Parcel`` objects support asynchronous message passing.

### Creating Parcels

Parcels which defined as ``Percel<T>`` can be receive only messages of the type ``T``.
For example, instances of ``Parcel<String>`` can receive only strings as message.

```
let p = Parcel<String>()
```

Next, you should define a message handler before starting waiting for messages.
A message handler can be set in parcels with ``onReceive(handler:)``.
``onReceive(handler:)`` takes a block which a parcel received a new message as an argument.

```
func onReceive(handler: @escaping (T) throws -> Loop)
```

Let's assume that print "Thunder" if a received message is "Flash" but otherwise print "Bye" the following:

```
let p = Parcel<String>()
p.onReceive { message in
    switch message {
    case "Flash":
        print("Thunder")
        return .continue
    default:
        print("Bye")
        return .break
    }
}
p.run()
```

Message handler blocks must return ``Loop.continue`` or ``Loop.break``.
``Loop.continue`` makes a parcel wait for messages again.
``Loop.break`` makes a parcel stop waiting for messages and release.
(Receive loop is written with recursive function in Erlang.
But Swift does not guarantee tail call optimization.)
Finally, invoke ``run`` to start waiting for messages.

The code from ``init()`` to ``run()`` can be replace with ``Parcel<T>.spawn()``.
``spawn()`` makes a new parcel start waiting for messages after got block is executed.

```
let p = Parcel<String>.spawn { p in
    p.onReceive { message in
        switch message {
        case "Flash":
            print("Thunder")
            return .continue
        default:
            print("Bye")
            return .break
        }
    }
}
```

### Sending Messages

Use ``!`` operator to send messages.
Left value of ``!`` operator is a parcel and right value is a message to send.

```
p ! "Flash" // --> "Thunder"
p ! "Fresh" // --> "Bye"
```

### Handling Timeout

- ``after(deadline:handler:)``

### Error and Exit Handling

- ``terminate(error:)``
- ``onTerminate(handler:)``

### Linking Parcels

- ``addLink(_:)``

### Monitoring Parcels

- ``addMonitor(_:)``

### Other APIs

- TCPSocket

## Package.swift

```
import PackageDescription

let package = Package(
    name: "YourApp",
    dependencies: [
        .Package(url: "https://github.com/szktty/parcel.git", majorVersion: 0),
    ]
)
```

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
