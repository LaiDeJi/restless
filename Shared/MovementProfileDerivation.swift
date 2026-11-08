import Foundation

/// One frame of a recorded movement trace, in plain values so the same shape can
/// cross from the watch, through WatchConnectivity, and into the phone.
struct MotionTraceSample: Codable, Hashable, Sendable {
    var time: TimeInterval
    var gravityX: Double
    var gravityY: Double
    var gravityZ: Double
    var accelerationX: Double
    var accelerationY: Double
    var accelerationZ: Double
    var rotationX: Double
    var rotationY: Double
    var rotationZ: Double

    init(
        time: TimeInterval,
        gravityX: Double = 0,
        gravityY: Double = 0,
        gravityZ: Double = 0,
        accelerationX: Double = 0,
        accelerationY: Double = 0,
        accelerationZ: Double = 0,
        rotationX: Double = 0,
        rotationY: Double = 0,
        rotationZ: Double = 0
    ) {
        self.time = time
        self.gravityX = gravityX
        self.gravityY = gravityY
        self.gravityZ = gravityZ
        self.accelerationX = accelerationX
        self.accelerationY = accelerationY
        self.accelerationZ = accelerationZ
        self.rotationX = rotationX
        self.rotationY = rotationY
        self.rotationZ = rotationZ
    }

    func gravity(_ axis: MovementAxis) -> Double {
        switch axis {
        case .x: gravityX
        case .y: gravityY
        case .z: gravityZ
        }
    }

    var accelerationVector: SIMD3<Double> {
        SIMD3(gravityX, gravityY, gravityZ)
    }
}

enum MovementProfileError: Error, Equatable, Sendable {
    case emptyTrace
    case tooFewCycles(Int)
    case noMotion
    case amplitudeTooLow(Double)
    case periodUnstable(Double)
}

/// Derives the four numbers the watch applies. This is a threshold calibration,
/// not a trained model.
///
/// The signal is the forearm elevation: the angle between gravity and the
/// watch's +Y axis, which runs along the forearm. A watch face turned up or
/// forward rotates around that axis and does not change the signal. A wrist
/// twist leaves it nearly constant, so twists do not count as reps.
enum MovementProfileDerivation {
    static let minimumCycles = 3
    /// Degrees of forearm elevation.
    static let minimumAmplitude = 15.0
    static let maximumPeriodVariation = 0.20
    static let localWindow: TimeInterval = 2.5
    /// The background recorder stores raw acceleration, so an average is needed
    /// to recover gravity. At 50 Hz this is 12–13 samples; a longer window
    /// erases the first cycle of a short recording.
    static let smoothingWindow: TimeInterval = 0.25
    static let minimumRepDuration: TimeInterval = 0.3
    static let clusterTolerance = 0.20

    // The whole cycle heuristic lives in this single pass; splitting it would
    // scatter the thresholds the derived profile depends on.
    // swiftlint:disable:next cyclomatic_complexity
    static func derive(from samples: [MotionTraceSample]) throws -> MovementProfile {
        guard samples.count >= 10 else { throw MovementProfileError.emptyTrace }
        let ordered = samples.sorted { $0.time < $1.time }
        let step = medianStep(ordered)

        let smoothWindow = max(3, Int((smoothingWindow / max(step, 0.001)).rounded()))
        let vectors = movingAverage(ordered.map(\.accelerationVector), window: smoothWindow)
        let angles = vectors.map(ForearmAngle.elevation)
        guard let low = angles.min(), let high = angles.max() else {
            throw MovementProfileError.emptyTrace
        }
        guard high - low >= 3 else { throw MovementProfileError.noMotion }
        let robust = percentileRange(angles, lower: 0.1, upper: 0.9)
        guard robust >= minimumAmplitude else {
            throw MovementProfileError.amplitudeTooLow(robust)
        }

        let window = max(5, Int((localWindow / max(step, 0.001)).rounded()))
        let ranges = rollingRanges(angles, window: window)

        var isUp = false
        var bottom = angles[0]
        var peak = angles[0]
        var cycles = 0
        var periods: [TimeInterval] = []
        var amplitudes: [Double] = []
        var lastValley: TimeInterval?
        var lastRep: TimeInterval = -.infinity

        for (index, value) in angles.enumerated() {
            let range = ranges[index]
            let amplitude = range.max - range.min
            guard amplitude >= minimumAmplitude else { continue }

            let rise = max(amplitude * 0.55, 5)
            let fall = max(amplitude * 0.45, 4)
            let time = ordered[index].time

            if isUp {
                peak = max(peak, value)
                if peak - value >= fall, time - lastRep >= minimumRepDuration {
                    cycles += 1
                    amplitudes.append(amplitude)
                    if let lastValley, time > lastValley {
                        periods.append(time - lastValley)
                    }
                    lastValley = time
                    lastRep = time
                    isUp = false
                    bottom = value
                    peak = value
                }
            } else {
                bottom = min(bottom, value)
                if value - bottom >= rise {
                    isUp = true
                    peak = value
                }
            }
        }

        guard cycles >= minimumCycles else {
            throw MovementProfileError.tooFewCycles(cycles)
        }
        guard periods.count >= 2 else {
            throw MovementProfileError.tooFewCycles(cycles)
        }

        let stable = stablePeriods(periods)
        guard stable.count >= 2 else {
            throw MovementProfileError.periodUnstable(variation(periods))
        }
        let mean = stable.reduce(0, +) / Double(stable.count)
        guard mean > 0 else { throw MovementProfileError.periodUnstable(1) }
        let spread = variation(stable)
        guard spread <= maximumPeriodVariation else {
            throw MovementProfileError.periodUnstable(spread)
        }

        let medianAmplitude = amplitudes.sorted()[amplitudes.count / 2]
        return MovementProfile(
            axis: .y,
            rise: max(5, medianAmplitude * 0.55),
            fall: max(4, medianAmplitude * 0.45),
            minPeriod: max(stable.min() ?? mean, 0.3)
        ).clamped()
    }

    private static func movingAverage(
        _ values: [SIMD3<Double>],
        window: Int
    ) -> [SIMD3<Double>] {
        guard window > 1, values.count >= window else { return values }
        let half = window / 2
        return values.indices.map { index in
            let lower = max(0, index - half)
            let upper = min(values.count - 1, index + half)
            let slice = values[lower...upper]
            return slice.reduce(SIMD3<Double>.zero, +) / Double(slice.count)
        }
    }

    private static func percentileRange(_ values: [Double], lower: Double, upper: Double) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let lowIndex = min(max(Int(Double(sorted.count) * lower), 0), sorted.count - 1)
        let highIndex = min(max(Int(Double(sorted.count) * upper), 0), sorted.count - 1)
        return max(0, sorted[highIndex] - sorted[lowIndex])
    }

    private static func medianStep(_ samples: [MotionTraceSample]) -> TimeInterval {
        let steps = zip(samples, samples.dropFirst())
            .map { $1.time - $0.time }
            .filter { $0 > 0 }
            .sorted()
        guard !steps.isEmpty else { return 0.02 }
        return steps[steps.count / 2]
    }

    private static func rollingRanges(
        _ values: [Double],
        window: Int
    ) -> [(min: Double, max: Double)] {
        var result: [(min: Double, max: Double)] = []
        result.reserveCapacity(values.count)
        for index in values.indices {
            let lower = max(0, index - window + 1)
            let slice = values[lower...index]
            result.append((slice.min() ?? 0, slice.max() ?? 0))
        }
        return result
    }

    /// Periods in the densest cluster. A slow setup rep sits outside it; a set
    /// that is genuinely unsteady has no cluster big enough to use.
    private static func stablePeriods(_ periods: [TimeInterval]) -> [TimeInterval] {
        var best: [TimeInterval] = []
        for seed in periods {
            let cluster = periods.filter { abs($0 - seed) <= seed * clusterTolerance }
            if cluster.count > best.count {
                best = cluster
            }
        }
        return best.count >= 3 ? best : periods
    }

    private static func variation(_ periods: [TimeInterval]) -> Double {
        guard periods.count > 1 else { return 1 }
        let mean = periods.reduce(0, +) / Double(periods.count)
        guard mean > 0 else { return 1 }
        let variance = periods.reduce(0) { $0 + pow($1 - mean, 2) } / Double(periods.count)
        return variance.squareRoot() / mean
    }
}
