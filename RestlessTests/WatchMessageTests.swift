import Foundation
import Testing
@testable import Restless

private func roundTrip(_ message: WatchMessage) throws -> WatchMessage {
    let data = try JSONEncoder().encode(message)
    return try JSONDecoder().decode(WatchMessage.self, from: data)
}

@Test func watchMessageRoundTripsArm() throws {
    let token = UUID()
    let movementID = UUID()
    let profile = MovementProfile(axis: .y, rise: 33, fall: 27, minPeriod: 0.9)
    let decoded = try roundTrip(.arm(token: token, movementID: movementID, profile: profile, target: 10))

    guard case .arm(let decodedToken, let decodedMovement, let decodedProfile, let target) = decoded else {
        Issue.record("expected arm")
        return
    }
    #expect(decodedToken == token)
    #expect(decodedMovement == movementID)
    #expect(decodedProfile == profile)
    #expect(target == 10)
}

@Test func watchMessageRoundTripsRecordingCases() throws {
    let requestID = UUID()
    let trace = [
        MotionTraceSample(time: 0, gravityX: 0.1, gravityY: 0.2, gravityZ: 0.3),
        MotionTraceSample(time: 0.02, gravityX: 0.4, gravityY: 0.5, gravityZ: 0.6)
    ]

    let startMessage = WatchMessage.startRecording(requestID: requestID, duration: 15)
    guard case .startRecording(let startID, let duration) = try roundTrip(startMessage) else {
        Issue.record("expected startRecording")
        return
    }
    #expect(startID == requestID)
    #expect(duration == 15)

    let traceMessage = WatchMessage.recordingTrace(requestID: requestID, samples: trace)
    guard case .recordingTrace(let traceID, let samples) = try roundTrip(traceMessage) else {
        Issue.record("expected recordingTrace")
        return
    }
    #expect(traceID == requestID)
    #expect(samples == trace)

    let failedMessage = WatchMessage.recordingFailed(requestID: requestID, reason: "NO MOTION DETECTED")
    guard case .recordingFailed(let failedID, let reason) = try roundTrip(failedMessage) else {
        Issue.record("expected recordingFailed")
        return
    }
    #expect(failedID == requestID)
    #expect(reason == "NO MOTION DETECTED")
}

@Test func tracePayloadRoundTrips() throws {
    let payload = RecordingTracePayload(
        requestID: UUID(),
        samples: [MotionTraceSample(time: 0.5, gravityY: -0.8)]
    )
    let data = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(RecordingTracePayload.self, from: data)
    #expect(decoded == payload)
}
