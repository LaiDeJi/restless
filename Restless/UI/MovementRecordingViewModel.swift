import Foundation
import Observation

enum MovementRecordingError: Error, Equatable, Sendable {
    case watchUnavailable
    case timeout
    case noTrace
    case cancelled
    /// The watch stopped the recording and named the reason.
    case watchFailed(String)
}

/// The phone asks the watch for a 15-second trace. The live implementation is
/// wired in `WatchRecordingService`; tests inject a fake.
protocol MovementRecordingService: Sendable {
    func startRecording() async throws -> [MotionTraceSample]
}

struct UnavailableMovementRecordingService: MovementRecordingService {
    func startRecording() async throws -> [MotionTraceSample] {
        throw MovementRecordingError.watchUnavailable
    }
}

@MainActor
@Observable
final class MovementRecordingViewModel {
    enum Phase: Equatable {
        case idle
        case waiting
        case received(MovementProfile)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var trace: [MotionTraceSample] = []

    private let service: any MovementRecordingService
    private let timeout: Duration

    init(
        service: any MovementRecordingService = UnavailableMovementRecordingService(),
        timeout: Duration = .seconds(240)
    ) {
        self.service = service
        self.timeout = timeout
    }

    func start() async {
        phase = .waiting
        trace = []
        do {
            let samples = try await withThrowingTaskGroup(of: [MotionTraceSample].self) { group in
                group.addTask { [service] in
                    try await service.startRecording()
                }
                group.addTask { [timeout] in
                    try await Task.sleep(for: timeout)
                    throw MovementRecordingError.timeout
                }
                guard let first = try await group.next() else {
                    throw MovementRecordingError.noTrace
                }
                group.cancelAll()
                return first
            }
            guard !samples.isEmpty else {
                phase = .failed(Self.message(for: MovementRecordingError.noTrace))
                return
            }
            trace = samples
            let profile = try MovementProfileDerivation.derive(from: samples)
            phase = .received(profile)
        } catch let error as MovementProfileError {
            phase = .failed(Self.message(for: error))
        } catch let error as MovementRecordingError {
            phase = .failed(Self.message(for: error))
        } catch {
            phase = .failed("RECORDING FAILED")
        }
    }

    func reset() {
        phase = .idle
        trace = []
    }

    static func message(for error: MovementRecordingError) -> String {
        switch error {
        case .watchUnavailable: "OPEN THE WATCH APP"
        case .timeout, .noTrace: "NO TRACE ARRIVED"
        case .cancelled: "RECORDING CANCELLED"
        case .watchFailed(let reason): reason
        }
    }

    static func message(for error: MovementProfileError) -> String {
        switch error {
        case .emptyTrace:
            "NO TRACE ARRIVED"
        case .tooFewCycles(let count):
            "ONLY \(count) CYCLES · NEED AT LEAST THREE"
        case .noMotion:
            "NO MOTION DETECTED"
        case .amplitudeTooLow:
            "NO MOTION DETECTED"
        case .periodUnstable:
            "UNSTEADY REPS · TRY AGAIN"
        }
    }
}
