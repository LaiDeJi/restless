import CoreMotion
import Foundation

/// One device-motion frame, converted to plain values so it can cross from
/// Core Motion's callback into the main actor without carrying a class.
struct MotionSample: Sendable {
    let time: TimeInterval
    let gravity: SIMD3<Double>
    let userAcceleration: SIMD3<Double>
    let rotationRate: SIMD3<Double>

    init(_ motion: CMDeviceMotion) {
        time = motion.timestamp
        gravity = SIMD3(motion.gravity.x, motion.gravity.y, motion.gravity.z)
        userAcceleration = SIMD3(
            motion.userAcceleration.x,
            motion.userAcceleration.y,
            motion.userAcceleration.z
        )
        rotationRate = SIMD3(
            motion.rotationRate.x,
            motion.rotationRate.y,
            motion.rotationRate.z
        )
    }
}
