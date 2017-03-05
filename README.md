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

class AreaActor: Actor<Area> {}

let ref = AreaActor.spawn {
    context, message in
    switch message {
    case .rectangle(let width, let height):
        print("Area of rectangle is \(width), \(height)")
    case .circle(let r):
        let circle = 3.14159 * r * r
        print("Area of circle is \(circle)")
    case .exit:
        print("Exit")
        context.terminate()
    }
}

// message passing
ref ! .rectangle(6, 10)
ref ! .circle(23)
ref ! .exit
```

Output:

```
Area of rectangle is 6, 10
Area of circle is 1661.9
Exit
```
