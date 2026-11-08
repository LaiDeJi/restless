import Foundation

/// The two-way watch protocol. The token makes a late message from an old set
/// harmless; the request id does the same for a recording.
enum WatchMessage: Codable, Hashable, Sendable {
    case arm(token: UUID, movementID: UUID, profile: MovementProfile, target: Int)
    case disarm
    case progress(token: UUID, reps: Int)
    case completion(token: UUID)

    case startRecording(requestID: UUID, duration: Int)
    case cancelRecording(requestID: UUID)
    case recordingFailed(requestID: UUID, reason: String)
    /// Built on the phone from a received trace file, never sent inline.
    case recordingTrace(requestID: UUID, samples: [MotionTraceSample])
}

/// The JSON payload of a trace file transferred from the watch.
struct RecordingTracePayload: Codable, Hashable, Sendable {
    var requestID: UUID
    var samples: [MotionTraceSample]
}

/// The capture window a recording uses. Long enough for three or more reps at a
/// normal tempo; the user can stop it early from the watch.
enum MovementRecording {
    static let duration = 15
}
