import Foundation
import Testing
@testable import Restless

private struct MockRecordingService: MovementRecordingService {
    let samples: [MotionTraceSample]
    let error: MovementRecordingError?

    init(samples: [MotionTraceSample] = [], error: MovementRecordingError? = nil) {
        self.samples = samples
        self.error = error
    }

    func startRecording() async throws -> [MotionTraceSample] {
        if let error { throw error }
        return samples
    }
}

private struct SlowRecordingService: MovementRecordingService {
    func startRecording() async throws -> [MotionTraceSample] {
        try await Task.sleep(for: .seconds(10))
        return []
    }
}

private func makeTrace(cycles: Int, amplitude: Double = 60) -> [MotionTraceSample] {
    let step = 0.02
    let count = Int(Double(cycles) / step)
    return (0...count).map { index in
        let time = Double(index) * step
        let angle = 90 + amplitude / 2 * sin(2 * .pi * time)
        let radians = angle * .pi / 180
        return MotionTraceSample(
            time: time,
            gravityY: cos(radians),
            gravityZ: sin(radians)
        )
    }
}

@MainActor
@Test("A clean watch trace is accepted with its profile")
func recordingAcceptsCleanTrace() async {
    let service = MockRecordingService(samples: makeTrace(cycles: 5))
    let model = MovementRecordingViewModel(service: service)

    await model.start()

    guard case .received(let profile) = model.phase else {
        Issue.record("Expected received, got \(model.phase)")
        return
    }
    #expect(profile.axis == .y)
    #expect(model.trace.count == makeTrace(cycles: 5).count)
}

@MainActor
@Test("A two-cycle trace is rejected with the cycle count")
func recordingRejectsTwoCycles() async {
    let service = MockRecordingService(samples: makeTrace(cycles: 2))
    let model = MovementRecordingViewModel(service: service)

    await model.start()

    #expect(model.phase == .failed("ONLY 2 CYCLES · NEED AT LEAST THREE"))
}

@MainActor
@Test("A flat trace reports no motion")
func recordingRejectsNoMotion() async {
    let flat = (0..<100).map { MotionTraceSample(time: Double($0) * 0.02) }
    let service = MockRecordingService(samples: flat)
    let model = MovementRecordingViewModel(service: service)

    await model.start()

    #expect(model.phase == .failed("NO MOTION DETECTED"))
}

@MainActor
@Test("A watch that never answers times out")
func recordingTimesOut() async {
    let model = MovementRecordingViewModel(
        service: SlowRecordingService(),
        timeout: .milliseconds(50)
    )

    await model.start()

    #expect(model.phase == .failed("NO TRACE ARRIVED"))
}

@MainActor
@Test("A watch failure reason is shown")
func recordingShowsWatchFailure() async {
    let service = MockRecordingService(error: .watchFailed("NO MOTION DETECTED"))
    let model = MovementRecordingViewModel(service: service)

    await model.start()

    #expect(model.phase == .failed("NO MOTION DETECTED"))
}
