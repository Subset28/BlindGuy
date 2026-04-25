import Foundation

/// At-most-once in-flight token for inference. Thread-safe, no allocation on acquire/release.
public final class FrameGate: @unchecked Sendable {
    private let lock = NSLock()
    private var inFlight = false

    public init() {}

    /// `true` if the caller may proceed; `false` if a frame is already in flight.
    @inline(__always)
    public func tryAcquire() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if inFlight { return false }
        inFlight = true
        return true
    }

    @inline(__always)
    public func release() {
        lock.lock()
        inFlight = false
        lock.unlock()
    }
}
