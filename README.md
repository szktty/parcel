# Parcel

Actor-based concurrency library for Swift (experimental)

## Usage

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
let actor = Actor<Area>.spawn {
    actor in

    // set callback when the actor receives a new message
    actor.onReceive {
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
actor ! .rectangle(6, 10)
actor ! .circle(23)
actor ! .exit
```

Output:

```
Area of rectangle is 6, 10
Area of circle is 1661.9
Exit
```
