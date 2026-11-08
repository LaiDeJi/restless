import Foundation
import Observation
import WatchKit

/// The watch side of a set. The phone arms it with a profile and a target; it
/// counts the watch arm, reports each rep, and completes at the target. A
/// workout session keeps the app alive with the wrist down.
///
/// Recording uses `CMSensorRecorder`, which keeps sampling while the app is
/// suspended, so the wrist can go down during the 15-second window.
@MainActor
@Observable
final class WatchSessionModel {
    enum Phase: Equatable {
        case ready
        case armed
        case counting
        case saved
        case recording
        case saving
        case unavailable
    }

    static let recordingDuration = 15

    private(set) var phase: Phase = .ready
    private(set) var reps = 0
    private(set) var target = 0
    private(set) var recordingRemaining = 0
    private(set) var note = "OPEN THE TIMER ON THE PHONE"

    private let link = WatchLinkSession.shared
    private let recorder = MotionRecorder()
    private let sensorRecorder = SensorRecorder()
    private let workout = WorkoutSession()

    private var streamTask: Task<Void, Never>?
    private var countingTask: Task<Void, Never>?
    @ObservationIgnored private var counter: ProfileRepCounter?
    private var forearmAngle = ForearmAngle()
    private var token: UUID?
    private var recordingID: UUID?
    private var recordingLimit: TimeInterval = 15
    private var recordingStart: Date?
    private var recordingTicker: Task<Void, Never>?
    private var recordingFetchTask: Task<Void, Never>?
    private var usesSensorRecorder = false
    private var isForeground = true

    // Live fallback when sensor recording is unavailable.
    private var recordingElapsed: TimeInterval = 0
    private var trace: [MotionTraceSample] = []
    private var traceStart: TimeInterval?
    private var traceOffset: TimeInterval = 0
    private var lastSampleTime: TimeInterval?

    var countText: String? {
        switch phase {
        case .armed: "0 OF \(target)"
        case .counting: "\(reps) OF \(target)"
        case .saved: target > 0 ? "\(reps) OF \(target)" : nil
        case .recording: "\(recordingRemaining)s"
        case .saving, .ready, .unavailable: nil
        }
    }

    var title: String {
        switch phase {
        case .ready: "READY"
        case .armed: "ARMED"
        case .counting: "COUNTING"
        case .saved: "SAVED"
        case .recording: "RECORDING"
        case .saving: "SAVING"
        case .unavailable: "UNAVAILABLE"
        }
    }

    var isCounting: Bool {
        phase == .armed || phase == .counting
    }

    // MARK: Lifecycle

    func activate() {
        link.activate()
        link.onMessage = { [weak self] message in
            self?.handle(message)
        }
    }

    func setForeground(_ foreground: Bool) {
        isForeground = foreground
        if foreground {
            if phase == .recording, usesSensorRecorder {
                if let start = recordingStart,
                   Date.now.timeIntervalSince(start) >= recordingLimit {
                    finishSensorRecording()
                } else if recordingTicker == nil {
                    startRecordingTicker()
                }
            } else if isCounting {
                // Without a workout session the app was suspended and the
                // stream may be stale; restart it. With one, the same stream
                // has been running the whole time.
                if !workout.isRunning {
                    stopMotion()
                }
                startCountingMotion()
            } else if phase == .recording, !usesSensorRecorder {
                startLiveRecordingMotion()
            }
        } else {
            // A running workout session keeps device motion alive with the
            // wrist down. Only the foreground-only recording path stops.
            if phase == .recording, !usesSensorRecorder {
                stopMotion()
            }
        }
    }

    // MARK: Messages

    private func handle(_ message: WatchMessage) {
        switch message {
        case .arm(let token, _, let profile, let target):
            beginCounting(token: token, profile: profile, target: target)
        case .disarm:
            clear()
        case .startRecording(let requestID, let duration):
            beginRecording(requestID: requestID, duration: duration)
        case .cancelRecording:
            clear()
        default:
            break
        }
    }

    private func beginCounting(token: UUID, profile: MovementProfile, target: Int) {
        stopMotion()
        self.token = token
        self.target = max(target, 1)
        reps = 0
        counter = ProfileRepCounter(profile: profile)
        forearmAngle = ForearmAngle()
        recordingID = nil
        trace = []
        phase = .armed
        note = "LIFT WHEN READY"
        Task { await workout.start() }
        startCountingMotion()
    }

    private func clear() {
        stopMotion()
        workout.stop()
        stopRecordingTicker()
        recordingFetchTask?.cancel()
        recordingFetchTask = nil
        token = nil
        counter = nil
        recordingID = nil
        recordingStart = nil
        usesSensorRecorder = false
        trace = []
        reps = 0
        recordingRemaining = 0
        target = 0
        phase = .ready
        note = "OPEN THE TIMER ON THE PHONE"
    }

    // MARK: Recording

    private func beginRecording(requestID: UUID, duration: Int) {
        stopMotion()
        workout.stop()
        token = nil
        counter = nil
        recordingID = requestID
        recordingLimit = TimeInterval(max(duration, 1))
        recordingStart = .now
        recordingRemaining = max(duration, 1)
        recordingElapsed = 0
        trace = []
        traceStart = nil
        traceOffset = 0
        lastSampleTime = nil
        phase = .recording

        if sensorRecorder.canRecord {
            usesSensorRecorder = true
            note = "RECORDING · HANDS FREE"
            sensorRecorder.start(duration: recordingLimit)
            startRecordingTicker()
        } else {
            usesSensorRecorder = false
            note = "RECORDING · KEEP MOVING"
            startLiveRecordingMotion()
        }
    }

    private func startRecordingTicker() {
        recordingTicker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                guard let start = self.recordingStart else { return }
                let elapsed = Date.now.timeIntervalSince(start)
                self.recordingElapsed = min(elapsed, self.recordingLimit)
                self.recordingRemaining = max(0, Int((self.recordingLimit - elapsed).rounded(.up)))
                if elapsed >= self.recordingLimit {
                    self.finishSensorRecording()
                    return
                }
            }
        }
    }

    private func stopRecordingTicker() {
        recordingTicker?.cancel()
        recordingTicker = nil
    }

    private func finishSensorRecording() {
        guard let requestID = recordingID, let start = recordingStart else { return }
        stopRecordingTicker()
        phase = .saving
        note = "FETCHING MOTION…"
        let end = start.addingTimeInterval(recordingLimit)

        recordingFetchTask = Task { [weak self] in
            guard let self else { return }
            for _ in 0..<90 {
                let samples = await self.sensorRecorder.samples(from: start, to: end)
                if samples.count >= 10 {
                    self.deliver(samples, requestID: requestID)
                    return
                }
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { return }
            }
            self.fail(requestID, reason: "NO TRACE ARRIVED")
        }
    }

    private func finishLiveRecording() {
        guard let requestID = recordingID else { return }
        stopMotion()
        WatchHaptics.success()

        if trace.count >= 10 {
            deliver(trace, requestID: requestID)
        } else {
            fail(requestID, reason: "NO MOTION DETECTED")
        }
    }

    private func deliver(_ samples: [MotionTraceSample], requestID: UUID) {
        guard recordingID == requestID else { return }
        let payload = RecordingTracePayload(requestID: requestID, samples: samples)
        if let url = writeTrace(payload) {
            _ = link.send(
                file: url,
                metadata: ["kind": "movement-trace", "requestID": requestID.uuidString]
            )
        }
        WatchHaptics.success()
        phase = .saved
        note = "TRACE SENT TO PHONE"
        resetRecording()
    }

    private func fail(_ requestID: UUID, reason: String) {
        guard recordingID == requestID else { return }
        link.send(.recordingFailed(requestID: requestID, reason: reason))
        phase = .unavailable
        note = reason
        resetRecording()
    }

    private func resetRecording() {
        recordingID = nil
        recordingStart = nil
        recordingRemaining = 0
        recordingElapsed = 0
        usesSensorRecorder = false
        trace = []
        traceStart = nil
        traceOffset = 0
        lastSampleTime = nil
        recordingFetchTask = nil
    }

    private func writeTrace(_ payload: RecordingTracePayload) -> URL? {
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = directory.appendingPathComponent("trace-\(payload.requestID.uuidString).json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: Motion

    private func startCountingMotion() {
        guard countingTask == nil else { return }
        guard let stream = recorder.start() else {
            phase = .unavailable
            note = "MOTION IS OFF ON THIS WATCH"
            return
        }

        countingTask = Task { [weak self] in
            for await sample in stream {
                guard let self else { return }
                self.ingestMotion(sample)
            }
        }
    }

    private func startLiveRecordingMotion() {
        guard isForeground else { return }
        guard streamTask == nil else { return }
        guard let stream = recorder.start() else {
            phase = .unavailable
            note = "MOTION IS OFF ON THIS WATCH"
            return
        }

        streamTask = Task { [weak self] in
            for await sample in stream {
                guard let self else { return }
                self.ingestLiveRecording(sample)
            }
        }
    }

    private func stopMotion() {
        streamTask?.cancel()
        streamTask = nil
        countingTask?.cancel()
        countingTask = nil
        recorder.stop()
    }

    private func ingestMotion(_ sample: MotionSample) {
        guard let token, var counter else { return }

        // Clean gravity, not raw acceleration: linear and centripetal
        // acceleration made a wrist twist look like a curl. The elevation uses
        // the +Y axis along the forearm, so the watch face can turn around the
        // forearm without changing the signal; the gyro check rejects a twist.
        let angle = forearmAngle.ingest(
            time: sample.time,
            acceleration: sample.gravity
        )
        let counted = counter.ingest(
            time: sample.time,
            value: angle,
            rotationX: sample.rotationRate.x,
            rotationY: sample.rotationRate.y,
            rotationZ: sample.rotationRate.z
        )
        self.counter = counter
        guard counted else { return }

        reps = counter.reps
        phase = .counting
        note = "\(reps) OF \(target) REPS"
        link.send(.progress(token: token, reps: reps))

        guard reps >= target else { return }
        link.send(.completion(token: token))
        WatchHaptics.success()
        workout.stop()
        stopMotion()
        self.token = nil
        self.counter = nil
        phase = .saved
        note = "SET DONE SENT"
    }

    /// Live fallback used only when background sensor recording is unavailable.
    private func ingestLiveRecording(_ sample: MotionSample) {
        if traceStart == nil {
            traceStart = sample.time
        }
        let base = traceStart ?? sample.time
        if let lastSampleTime, sample.time - lastSampleTime > 0.5 {
            traceOffset += sample.time - lastSampleTime
        }
        lastSampleTime = sample.time
        let time = sample.time - base - traceOffset

        recordingElapsed = time
        recordingRemaining = max(0, Int((recordingLimit - time).rounded(.up)))

        // Store raw acceleration so the phone derives the same signal the
        // counting path uses.
        let raw = sample.gravity + sample.userAcceleration
        trace.append(
            MotionTraceSample(
                time: time,
                gravityX: raw.x,
                gravityY: raw.y,
                gravityZ: raw.z,
                accelerationX: sample.userAcceleration.x,
                accelerationY: sample.userAcceleration.y,
                accelerationZ: sample.userAcceleration.z,
                rotationX: sample.rotationRate.x,
                rotationY: sample.rotationRate.y,
                rotationZ: sample.rotationRate.z
            )
        )

        if recordingElapsed >= recordingLimit {
            finishLiveRecording()
        }
    }
}

enum WatchHaptics {
    static func success() {
        WKInterfaceDevice.current().play(.success)
    }
}
