import Foundation
import Testing
@testable import Restless

/// A forearm elevation trace: the angle between gravity and the watch's +Y
/// axis swings around a mid angle. The acceleration vector is built from that
/// angle so the derivation sees exactly what the watch sees.
private func trace(
    cycles: Int,
    period: Double = 1,
    amplitude: Double = 60
) -> [MotionTraceSample] {
    let step = 0.02
    let count = Int((Double(cycles) * period) / step)
    var samples: [MotionTraceSample] = []
    for index in 0...count {
        let time = Double(index) * step
        let angle = 90 + amplitude / 2 * sin(2 * .pi * time / period)
        let radians = angle * .pi / 180
        samples.append(
            MotionTraceSample(
                time: time,
                gravityY: cos(radians),
                gravityZ: sin(radians)
            )
        )
    }
    return samples
}

private func variableTrace(periods: [Double], amplitude: Double = 60) -> [MotionTraceSample] {
    let step = 0.02
    var samples: [MotionTraceSample] = []
    var time = 0.0
    for period in periods {
        let count = max(Int(period / step), 2)
        for index in 0..<count {
            let phase = 2 * Double.pi * Double(index) / Double(count)
            let angle = 90 + amplitude / 2 * sin(phase)
            let radians = angle * .pi / 180
            samples.append(
                MotionTraceSample(
                    time: time,
                    gravityY: cos(radians),
                    gravityZ: sin(radians)
                )
            )
            time += step
        }
    }
    return samples
}

private func expectProfileError(
    _ expected: MovementProfileError,
    _ samples: [MotionTraceSample],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    do {
        _ = try MovementProfileDerivation.derive(from: samples)
        Issue.record("Expected \(expected) but derivation succeeded", sourceLocation: sourceLocation)
    } catch let error as MovementProfileError {
        #expect(error == expected, sourceLocation: sourceLocation)
    } catch {
        Issue.record("Expected MovementProfileError, got \(error)", sourceLocation: sourceLocation)
    }
}

@Test("A clean five-rep trace derives the forearm thresholds")
func cleanTraceDerivesProfile() throws {
    let profile = try MovementProfileDerivation.derive(from: trace(cycles: 5, period: 1))

    #expect(profile.axis == .y)
    #expect(abs(profile.rise - 29) < 2)
    #expect(abs(profile.fall - 24) < 2)
    #expect(abs(profile.minPeriod - 1.0) < 0.05)
    #expect(profile.usesForearmSignal)
}

@Test("Two cycles are rejected")
func twoCyclesRejected() {
    expectProfileError(.tooFewCycles(2), trace(cycles: 2))
}

@Test("A trace with no motion is rejected")
func noMotionRejected() {
    let samples = (0..<100).map {
        MotionTraceSample(time: Double($0) * 0.02, gravityY: 1)
    }
    expectProfileError(.noMotion, samples)
}

@Test("A trace below the amplitude floor is rejected")
func lowAmplitudeRejected() {
    let samples = trace(cycles: 5, amplitude: 10)
    do {
        _ = try MovementProfileDerivation.derive(from: samples)
        Issue.record("Expected amplitude rejection")
    } catch let error as MovementProfileError {
        guard case .amplitudeTooLow = error else {
            Issue.record("Expected amplitudeTooLow, got \(error)")
            return
        }
    } catch {
        Issue.record("Expected MovementProfileError, got \(error)")
    }
}

@Test("An unstable period is rejected")
func unstablePeriodRejected() {
    let samples = variableTrace(periods: [1.0, 2.2, 3.4])
    do {
        _ = try MovementProfileDerivation.derive(from: samples)
        Issue.record("Expected period rejection")
    } catch let error as MovementProfileError {
        guard case .periodUnstable = error else {
            Issue.record("Expected periodUnstable, got \(error)")
            return
        }
    } catch {
        Issue.record("Expected MovementProfileError, got \(error)")
    }
}

/// A big wrist movement before the set, then five smaller but steady reps. The
/// local amplitude must follow the reps instead of the setup swing.
private func outlierThenRepsTrace() -> [MotionTraceSample] {
    let step = 0.02
    var samples: [MotionTraceSample] = []
    var time = 0.0

    func append(angle: Double) {
        let radians = angle * .pi / 180
        samples.append(
            MotionTraceSample(
                time: time,
                gravityY: cos(radians),
                gravityZ: sin(radians)
            )
        )
        time += step
    }

    for index in 0..<100 {
        let phase = 2 * Double.pi * Double(index) / 100
        append(angle: 90 + 60 * sin(phase))
    }
    for _ in 0..<150 {
        append(angle: 90)
    }
    for _ in 0..<5 {
        for index in 0..<50 {
            let phase = 2 * Double.pi * Double(index) / 50
            append(angle: 90 + 20 * sin(phase))
        }
    }
    return samples
}

@Test("A big setup swing does not hide steady reps")
func setupSwingDoesNotHideReps() throws {
    let profile = try MovementProfileDerivation.derive(from: outlierThenRepsTrace())
    #expect(profile.axis == .y)
    #expect(profile.minPeriod > 0.8 && profile.minPeriod < 1.1)
    #expect(profile.rise < 30)
    #expect(profile.fall < 25)
}

@Test("An empty trace is rejected")
func emptyTraceRejected() {
    expectProfileError(.emptyTrace, [])
}
