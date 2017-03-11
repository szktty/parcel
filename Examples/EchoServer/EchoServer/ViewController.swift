import Cocoa

class ViewController: NSViewController {

    var server: EchoServer!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        server = EchoServer(address: "127.0.0.1", port: 8080)
        server.run()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

