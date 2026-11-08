import Foundation

/// Asks the watch for a 15-second trace. The request is tokenized, so a late
/// trace from an abandoned attempt is ignored.
struct WatchRecordingService: MovementRecordingService {
    func startRecording() async throws -> [MotionTraceSample] {
        try await WatchRecordingBroker.shared.start()
    }
}

@MainActor
final class WatchRecordingBroker {
    static let shared = WatchRecordingBroker()

    private struct Pending {
        let requestID: UUID
        let continuation: CheckedContinuation<[MotionTraceSample], Error>
    }

    private let transport = WatchSessionTransport.shared
    private var observer: UUID?
    private var pending: Pending?

    func start() async throws -> [MotionTraceSample] {
        transport.activate()
        let requestID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending = Pending(requestID: requestID, continuation: continuation)
                observer = transport.observe { [weak self] message in
                    self?.handle(message)
                }
                transport.send(.startRecording(requestID: requestID, duration: MovementRecording.duration))
            }
        } onCancel: {
            Task { @MainActor in
                self.cancel(requestID)
            }
        }
    }

    private func handle(_ message: WatchMessage) {
        switch message {
        case .recordingTrace(let requestID, let samples):
            finish(.success(samples), for: requestID)
        case .recordingFailed(let requestID, let reason):
            finish(.failure(MovementRecordingError.watchFailed(reason)), for: requestID)
        default:
            break
        }
    }

    private func cancel(_ requestID: UUID) {
        guard pending?.requestID == requestID else { return }
        transport.send(.cancelRecording(requestID: requestID))
        finish(.failure(MovementRecordingError.cancelled), for: requestID)
    }

    private func finish(_ result: Result<[MotionTraceSample], Error>, for requestID: UUID) {
        guard let pending, pending.requestID == requestID else { return }
        self.pending = nil
        if let observer {
            transport.removeObserver(observer)
        }
        observer = nil
        pending.continuation.resume(with: result)
    }
}
