import CoreMotion
import Foundation

@MainActor
final class MotionRecorder {
    private let manager = CMMotionManager()
    private var continuation: AsyncStream<MotionSample>.Continuation?

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    /// Device motion, used by set counting and the curl lab. Gravity is the
    /// clean orientation signal; user acceleration and rotation rate come along
    /// for the recording trace and the twist check.
    func start() -> AsyncStream<MotionSample>? {
        guard manager.isDeviceMotionAvailable else { return nil }
        manager.deviceMotionUpdateInterval = 1.0 / 50.0

        let (stream, continuation) = AsyncStream<MotionSample>.makeStream()
        self.continuation = continuation
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion else { return }
            continuation.yield(MotionSample(motion))
        }
        return stream
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        continuation?.finish()
        continuation = nil
    }
}
