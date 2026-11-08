import Foundation

/// Applies a recorded profile to the live forearm elevation signal. The watch
/// does not learn during a set: `rise` and `fall` are degrees inside the
/// recorded amplitude, and `minPeriod` is the debounce between reps.
struct ProfileRepCounter: Sendable {
    let profile: MovementProfile
    private(set) var reps = 0

    private var bottom: Double?
    private var peak: Double = 0
    private var isUp = false
    private var lastRepTime: TimeInterval = -.infinity
    private var smoothed: Double?
    private var lastTime: TimeInterval?

    // Gyro energy during the upward phase. The forearm runs along the watch's
    // +Y axis, so a wrist twist turns about Y while elbow flexion turns about
    // X or Z. Comparing the two energies rejects a twist that still moves the
    // arm, and using X² + Z² keeps the check independent of how the watch face
    // is rotated around the forearm.
    private var hasRotation = false
    private var flexionEnergy = 0.0
    private var twistEnergy = 0.0

    init(profile: MovementProfile) {
        self.profile = profile.clamped()
    }

    var axis: MovementAxis { profile.axis }

    /// Returns true on the sample that completed a rep. Pass the gyro rate when
    /// the source has it; the twist check is skipped when it does not.
    mutating func ingest(
        time: TimeInterval,
        value raw: Double,
        rotationX: Double? = nil,
        rotationY: Double? = nil,
        rotationZ: Double? = nil
    ) -> Bool {
        let value = filter(raw, at: time)
        guard var low = bottom else {
            bottom = value
            peak = value
            return false
        }

        let rise = max(profile.rise, 1)
        let fall = max(profile.fall, 1)
        var counted = false

        if isUp {
            if hasRotation {
                let x = rotationX ?? 0
                let y = rotationY ?? 0
                let z = rotationZ ?? 0
                flexionEnergy += x * x + z * z
                twistEnergy += y * y
            }
            peak = max(peak, value)
            if peak - value >= fall,
               time - lastRepTime >= profile.minPeriod,
               twistAllowsRep {
                reps += 1
                lastRepTime = time
                isUp = false
                low = value
                peak = value
                flexionEnergy = 0
                twistEnergy = 0
                counted = true
            }
        } else {
            low = min(low, value)
            if value - low >= rise {
                isUp = true
                peak = value
                hasRotation = rotationX != nil || rotationY != nil || rotationZ != nil
                let x = rotationX ?? 0
                let y = rotationY ?? 0
                let z = rotationZ ?? 0
                flexionEnergy = x * x + z * z
                twistEnergy = y * y
            }
        }

        bottom = low
        return counted
    }

    /// True when the upward phase was elbow flexion, not a wrist twist. No gyro
    /// samples means no evidence of a twist, so the rep is allowed.
    private var twistAllowsRep: Bool {
        guard hasRotation else { return true }
        return flexionEnergy > twistEnergy * 1.05
    }

    private mutating func filter(_ raw: Double, at time: TimeInterval) -> Double {
        defer { lastTime = time }
        guard let smoothed, let lastTime else {
            self.smoothed = raw
            return raw
        }
        let dt = max(0, time - lastTime)
        let alpha = 1 - exp(-dt / 0.08)
        let value = smoothed + (raw - smoothed) * alpha
        self.smoothed = value
        return value
    }
}

/// The angle between the acceleration vector and the watch's +Y axis, in
/// degrees. The +Y axis runs along the forearm, so turning the watch face up or
/// forward around the forearm does not change this signal. A wrist twist leaves
/// it nearly constant, which is why twists do not count as reps.
struct ForearmAngle: Sendable {
    private var filtered: SIMD3<Double>?
    private var lastTime: TimeInterval?

    mutating func ingest(time: TimeInterval, acceleration: SIMD3<Double>) -> Double {
        let vector: SIMD3<Double>
        if let filtered, let lastTime {
            let dt = max(0, time - lastTime)
            let alpha = 1 - exp(-dt / 0.12)
            vector = filtered + (acceleration - filtered) * alpha
        } else {
            vector = acceleration
        }
        self.filtered = vector
        self.lastTime = time
        return Self.elevation(vector)
    }

    static func elevation(_ acceleration: SIMD3<Double>) -> Double {
        let length = (acceleration.x * acceleration.x
            + acceleration.y * acceleration.y
            + acceleration.z * acceleration.z).squareRoot()
        guard length > 0 else { return 0 }
        let y = min(max(acceleration.y / length, -1), 1)
        return acos(y) * 180 / .pi
    }
}

extension SIMD3<Double> {
    func component(_ axis: MovementAxis) -> Double {
        switch axis {
        case .x: x
        case .y: y
        case .z: z
        }
    }
}
