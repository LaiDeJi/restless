import Foundation
import Observation

@MainActor
@Observable
final class RepLabModel {
    enum Phase: Sendable {
        case idle
        case calibrating
        case active
        case saving
        case finished
    }

    private struct LoggedSample: Sendable {
        let sample: MotionSample
        let angle: Double
        let swing: Double
        let reps: Int
        let bottom: Double
        let peak: Double
    }

    private(set) var phase: Phase = .idle
    private(set) var reps = 0
    private(set) var angle: Double = 0
    private(set) var elapsed: TimeInterval = 0
    private(set) var sampleCount = 0
    private(set) var errorMessage: String?
    private(set) var transferNote = ""

    private let recorder = MotionRecorder()
    private let transfer = WatchLinkSession.shared

    private var detector = RepDetector()
    private var samples: [LoggedSample] = []
    private var streamTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?
    private var firstSampleTime: TimeInterval?
    private var lastUIUpdate: TimeInterval = 0
    private var startedAt: Date?

    var primaryTitle: String {
        switch phase {
        case .idle: "START SET"
        case .calibrating: "STOP"
        case .active: "STOP SET"
        case .saving: "SAVING…"
        case .finished: "NEW SET"
        }
    }

    var statusText: String {
        switch phase {
        case .idle:
            "Arm down, screen on"
        case .calibrating:
            "Hold your arm down"
        case .active:
            "\(clockString(Int(elapsed))) · set in progress"
        case .saving:
            "Writing log…"
        case .finished:
            "\(clockString(Int(elapsed))) · \(sampleCount) samples"
        }
    }

    private var phaseName: String {
        switch phase {
        case .idle: "idle"
        case .calibrating: "calibrating"
        case .active: "active"
        case .saving: "saving"
        case .finished: "finished"
        }
    }

    func performPrimaryAction() {
        switch phase {
        case .idle, .finished:
            startSet()
        case .calibrating, .active:
            stopSet()
        case .saving:
            break
        }
    }

    private func startSet() {
        guard phase == .idle || phase == .finished else { return }

        errorMessage = nil
        transferNote = ""
        reps = 0
        angle = 0
        elapsed = 0
        sampleCount = 0
        samples.removeAll(keepingCapacity: true)
        firstSampleTime = nil
        lastUIUpdate = 0
        detector.beginCalibration()
        phase = .calibrating
        emitTelemetry()

        Task { [weak self] in
            self?.begin()
        }
    }

    private func begin() {
        guard let stream = recorder.start() else {
            errorMessage = "Motion is unavailable on this device."
            phase = .idle
            return
        }

        startedAt = .now
        streamTask = Task { [weak self] in
            for await sample in stream {
                guard let self else { return }
                self.ingest(sample)
            }
        }
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self else { return }
                self.tick()
            }
        }
    }

    private func ingest(_ sample: MotionSample) {
        if firstSampleTime == nil {
            firstSampleTime = sample.time
        }

        let reading = detector.ingest(sample)
        if detector.isCalibrated, phase == .calibrating {
            phase = .active
        }
        if reading.countedRep {
            reps = detector.repCount
        }

        samples.append(
            LoggedSample(
                sample: sample,
                angle: reading.angle,
                swing: reading.swing,
                reps: detector.repCount,
                bottom: reading.bottom,
                peak: reading.peak
            )
        )

        // The watch only needs to redraw about ten times a second. The motion
        // stream keeps running at 50 Hz for the detector and the log.
        if sample.time - lastUIUpdate >= 0.1 {
            angle = reading.swing
            sampleCount = samples.count
            if let firstSampleTime {
                elapsed = sample.time - firstSampleTime
            }
            lastUIUpdate = sample.time
            emitTelemetry()
        }

        if elapsed > 300 {
            stopSet()
        }
    }

    private func tick() {
        guard let startedAt else { return }
        elapsed = max(elapsed, Date.now.timeIntervalSince(startedAt))
    }

    private func stopSet() {
        guard phase == .active || phase == .calibrating else { return }

        phase = .saving
        recorder.stop()
        streamTask?.cancel()
        streamTask = nil
        tickerTask?.cancel()
        tickerTask = nil

        Task { [weak self] in
            self?.finish()
        }
    }

    private func finish() {
        if let url = writeLog() {
            transferNote = transfer.send(file: url, metadata: ["kind": "curl-log"])
                ? "Log queued for iPhone"
                : "Log saved on watch"
        } else {
            transferNote = "No samples to save"
        }

        phase = .finished
        emitTelemetry()
    }

    private func writeLog() -> URL? {
        guard let first = samples.first else { return nil }

        let base = first.sample.time
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = directory.appendingPathComponent("curl-\(Self.fileStamp()).csv")

        var csv = "time,gx,gy,gz,ax,ay,az,rx,ry,rz,angle,swing,reps,bottom,peak\n"
        csv.reserveCapacity(samples.count * 120)
        for logged in samples {
            let sample = logged.sample
            csv += [
                Self.format(sample.time - base),
                Self.format(sample.gravity.x),
                Self.format(sample.gravity.y),
                Self.format(sample.gravity.z),
                Self.format(sample.userAcceleration.x),
                Self.format(sample.userAcceleration.y),
                Self.format(sample.userAcceleration.z),
                Self.format(sample.rotationRate.x),
                Self.format(sample.rotationRate.y),
                Self.format(sample.rotationRate.z),
                Self.format(logged.angle),
                Self.format(logged.swing),
                "\(logged.reps)",
                Self.format(logged.bottom),
                Self.format(logged.peak)
            ].joined(separator: ",")
            csv += "\n"
        }

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            errorMessage = "Could not save log: \(error.localizedDescription)"
            return nil
        }
    }

    /// Also written to stdout so `devicectl device process launch --console`
    /// can feed the Mac live trace without involving the phone.
    private func emitTelemetry() {
        let line = "CURL,\(Self.format(elapsed)),\(Self.format(angle)),\(reps),\(phaseName),\(Self.format(detector.bottom)),\(Self.format(detector.peak))\n"
        // Here `angle` is the forearm swing, not the raw gravity angle.
        FileHandle.standardOutput.write(Data(line.utf8))
    }

    private static func format(_ value: Double) -> String {
        String(
            format: "%.4f",
            locale: Locale(identifier: "en_US_POSIX"),
            arguments: [value]
        )
    }

    private static func fileStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: .now)
    }
}
