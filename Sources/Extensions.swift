import Foundation

extension DispatchTime {

    public static func after(milliseconds: UInt) -> DispatchTime {
        return .now() + .milliseconds(Int(milliseconds))
    }

}

extension DispatchQueue {
    
    public func asyncAfter(timeout: UInt, execute: @escaping () -> Void)
        -> DispatchWorkItem
    {
        let item = DispatchWorkItem(block: execute)
        asyncAfter(deadline: DispatchTime.after(milliseconds: timeout),
                   execute: item)
        return item
    }
    
    public func asyncAfter(timeout: UInt, execute: DispatchWorkItem) {
        asyncAfter(deadline: DispatchTime.after(milliseconds: timeout),
                   execute: execute)
    }
    
}
