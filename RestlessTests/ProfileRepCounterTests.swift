import Foundation
import Testing
@testable import Restless

/// A forearm elevation signal in degrees, as the watch produces it.
private func signal(
    cycles: Int,
    period: Double = 1,
    amplitude: Double = 60,
    step: Double = 0.02
) -> [(time: TimeInterval, value: Double)] {
    let count = Int((Double(cycles) * period) / step)
    return (0...count).map { index in
        let time = Double(index) * step
        let value = 60 + amplitude / 2 * sin(2 * .pi * time / period)
        return (time, value)
    }
}

private let profile = MovementProfile(axis: .y, rise: 20, fall: 15, minPeriod: 0.5)

@Test func profileCounterCountsSteadyCycles() {
    var counter = ProfileRepCounter(profile: profile)
    var reps = 0
    for frame in signal(cycles: 5) where counter.ingest(time: frame.time, value: frame.value) {
        reps += 1
    }
    #expect(reps == 5)
    #expect(counter.reps == 5)
}

@Test func profileCounterIgnoresStillMotion() {
    var counter = ProfileRepCounter(profile: profile)
    for index in 0..<250 {
        _ = counter.ingest(time: Double(index) * 0.02, value: 60)
    }
    #expect(counter.reps == 0)
}

@Test func profileCounterHonoursMinimumPeriod() {
    var counter = ProfileRepCounter(profile: profile)
    // Two full cycles inside the debounce: at most one rep.
    for frame in signal(cycles: 2, period: 0.2, step: 0.005) {
        _ = counter.ingest(time: frame.time, value: frame.value)
    }
    #expect(counter.reps <= 1)
}

@Test func profileCounterIgnoresSmallOscillation() {
    var counter = ProfileRepCounter(profile: profile)
    for frame in signal(cycles: 6, amplitude: 6) {
        _ = counter.ingest(time: frame.time, value: frame.value)
    }
    #expect(counter.reps == 0)
}

@Test func profileCounterRejectsWristTwist() {
    var counter = ProfileRepCounter(profile: profile)
    // The elevation swings enough to cross the thresholds, but the gyro says
    // the motion is mostly a twist about the forearm (Y), not elbow flexion (X).
    for frame in signal(cycles: 5) {
        _ = counter.ingest(
            time: frame.time,
            value: frame.value,
            rotationX: 0.05,
            rotationY: 1.2
        )
    }
    #expect(counter.reps == 0)
}

@Test func profileCounterAcceptsElbowFlexion() {
    var counter = ProfileRepCounter(profile: profile)
    for frame in signal(cycles: 5) {
        _ = counter.ingest(
            time: frame.time,
            value: frame.value,
            rotationX: 1.2,
            rotationY: 0.05
        )
    }
    #expect(counter.reps == 5)
}

@Test func forearmAngleIgnoresWatchFaceRotation() {
    // A watch face turned around the forearm rotates the acceleration around
    // +Y; the elevation angle must not change.
    let base = SIMD3(0.0, 0.6, 0.8)
    let turned = SIMD3(0.0, 0.6, -0.8)
    let baseAngle = ForearmAngle.elevation(base)
    let turnedAngle = ForearmAngle.elevation(turned)
    #expect(abs(baseAngle - turnedAngle) < 0.001)
}
