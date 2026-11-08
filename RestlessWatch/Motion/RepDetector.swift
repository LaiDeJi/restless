import Foundation

/// Counts curl cycles from wrist motion.
///
/// A wrist twist also rotates the watch, so the full gravity angle is not enough:
/// supination/pronation swings the watch around the forearm without bending the
/// elbow. The detector therefore uses the *forearm elevation* — the angle
/// between gravity and the watch's +Y axis, which runs along the forearm. A
/// curl changes that angle; a wrist twist leaves it roughly constant.
///
/// The rep test is relative to the movement:
/// - keep the lowest forearm swing since the last count;
/// - arm is up once the swing rises `riseThreshold` above that low;
/// - count when it falls `fallThreshold` from the peak;
/// - require the upward phase to be dominated by rotation about the watch's
///   X axis (elbow flexion), not the forearm's Y axis (a wrist twist).
///
/// A refractory period keeps a shaky bottom from counting twice.
struct RepDetector: Sendable {
    struct Reading: Sendable {
        /// Full gravity direction change; useful as a raw trace but fooled by twists.
        let angle: Double
        /// Forearm elevation change; the signal the rep test uses.
        let swing: Double
        let countedRep: Bool
        let bottom: Double
        let peak: Double
    }

    private enum State: Sendable {
        case down
        case up
    }

    private(set) var repCount = 0
    private(set) var isCalibrated = false
    private(set) var bottom: Double = 0
    private(set) var peak: Double = 0

    private let calibrationDuration: TimeInterval = 1.0
    private let riseThreshold: Double = 50
    private let fallThreshold: Double = 40
    private let minimumRepDuration: TimeInterval = 0.6
    private let axisRatio: Double = 1.05
    private let filterTimeConstant: TimeInterval = 0.08

    private var baseline: SIMD3<Double>?
    private var baselineForearmAngle: Double = 0
    private var calibrationStart: TimeInterval?
    private var calibrationSum = SIMD3<Double>.zero
    private var calibrationCount = 0
    private var filteredAngle: Double = 0
    private var filteredSwing: Double = 0
    private var lastSampleTime: TimeInterval?
    private var lastRepTime: TimeInterval = -.infinity
    private var state: State = .down
    private var hasBottom = false
    private var xEnergy: Double = 0
    private var yEnergy: Double = 0

    mutating func beginCalibration() {
        repCount = 0
        isCalibrated = false
        bottom = 0
        peak = 0
        hasBottom = false
        baseline = nil
        baselineForearmAngle = 0
        calibrationStart = nil
        calibrationSum = .zero
        calibrationCount = 0
        filteredAngle = 0
        filteredSwing = 0
        lastSampleTime = nil
        lastRepTime = -.infinity
        state = .down
        xEnergy = 0
        yEnergy = 0
    }

    mutating func ingest(_ sample: MotionSample) -> Reading {
        let gravity = normalized(sample.gravity)

        guard isCalibrated, let baseline else {
            if calibrationStart == nil { calibrationStart = sample.time }
            calibrationSum += gravity
            calibrationCount += 1

            let calibrationElapsed = sample.time - (calibrationStart ?? sample.time)
            if calibrationElapsed >= calibrationDuration, calibrationCount > 5 {
                let averaged = normalized(calibrationSum)
                self.baseline = averaged
                baselineForearmAngle = forearmAngle(of: averaged)
                isCalibrated = true
                lastSampleTime = sample.time
            }
            return Reading(angle: 0, swing: 0, countedRep: false, bottom: 0, peak: 0)
        }

        let rawAngle = acos(clamped(dot(gravity, baseline), -1, 1)) * 180 / .pi
        let rawSwing = abs(forearmAngle(of: gravity) - baselineForearmAngle)
        let deltaTime = max(0, sample.time - (lastSampleTime ?? sample.time))
        lastSampleTime = sample.time
        let alpha = 1 - exp(-deltaTime / filterTimeConstant)
        filteredAngle += (rawAngle - filteredAngle) * alpha
        filteredSwing += (rawSwing - filteredSwing) * alpha

        if !hasBottom {
            bottom = filteredSwing
            peak = filteredSwing
            hasBottom = true
        }

        var countedRep = false
        switch state {
        case .down:
            if filteredSwing < bottom {
                bottom = filteredSwing
            }
            if filteredSwing >= bottom + riseThreshold {
                state = .up
                peak = filteredSwing
                xEnergy = sample.rotationRate.x * sample.rotationRate.x
                yEnergy = sample.rotationRate.y * sample.rotationRate.y
            }

        case .up:
            if filteredSwing > peak {
                peak = filteredSwing
            }
            xEnergy += sample.rotationRate.x * sample.rotationRate.x
            yEnergy += sample.rotationRate.y * sample.rotationRate.y

            if filteredSwing <= peak - fallThreshold,
               sample.time - lastRepTime >= minimumRepDuration {
                // A real curl is mostly elbow flexion: the gyro X energy wins.
                // A wrist twist is mostly forearm rotation: gyro Y wins.
                if xEnergy > yEnergy * axisRatio {
                    repCount += 1
                    lastRepTime = sample.time
                    countedRep = true
                }
                state = .down
                bottom = filteredSwing
                peak = filteredSwing
                xEnergy = 0
                yEnergy = 0
            }
        }

        return Reading(
            angle: filteredAngle,
            swing: filteredSwing,
            countedRep: countedRep,
            bottom: bottom,
            peak: peak
        )
    }

    private func forearmAngle(of gravity: SIMD3<Double>) -> Double {
        acos(clamped(gravity.y, -1, 1)) * 180 / .pi
    }

    private func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        a.x * b.x + a.y * b.y + a.z * b.z
    }

    private func normalized(_ vector: SIMD3<Double>) -> SIMD3<Double> {
        let length = dot(vector, vector).squareRoot()
        return length > 0 ? vector / length : vector
    }

    private func clamped(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
