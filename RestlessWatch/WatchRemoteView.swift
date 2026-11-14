import SwiftUI

/// One screen for every phase. The phone publishes the words and the accent;
/// this view only chooses where to put them.
struct WatchRemoteView: View {
    @Environment(WatchRemoteModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let snapshot = model.snapshot, let payload = model.payload {
                remote(snapshot, payload: payload)
            } else {
                empty
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.refreshDisplay()
            } else {
                model.pauseDisplayRefresh()
            }
        }
    }

    private func remote(_ snapshot: SessionSnapshot, payload: WatchSessionPayload) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(phaseLabel(snapshot))
                .font(Theme.TypeScale.label)
                .tracking(1.4)
                .foregroundStyle(snapshot.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title(snapshot, payload: payload))
                .font(Theme.TypeScale.rowTitle)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.top, 2)

            if let position = positionLabel(snapshot) {
                Text(position)
                    .font(Theme.TypeScale.micro)
                    .tracking(0.8)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(snapshot.phase == .done ? 2 : 1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 2)
            }

            WatchSetBar(done: snapshot.doneSets, total: snapshot.totalSets, accent: snapshot.accentColor)
                .padding(.top, 8)

            Text(countLabel(snapshot))
                .font(Theme.TypeScale.micro)
                .tracking(0.8)
                .foregroundStyle(Theme.tertiaryText)
                .padding(.top, 4)

            if model.sendFailed {
                Text("NOT SENT · TRY AGAIN")
                    .font(Theme.TypeScale.micro)
                    .tracking(0.8)
                    .foregroundStyle(Theme.roundAccent)
                    .padding(.top, 6)
            }

            Spacer(minLength: 6)

            actions(snapshot)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private func actions(_ snapshot: SessionSnapshot) -> some View {
        HStack(spacing: 8) {
            Button {
                model.send(snapshot.primaryAction)
            } label: {
                Text(snapshot.primaryTitle)
                    .font(Theme.TypeScale.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .foregroundStyle(Theme.ink)
                    .background(snapshot.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)

            if snapshot.phase == .resting {
                Button {
                    model.send(.skipRest)
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 38, height: 38)
                        .foregroundStyle(.white)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip rest")
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text("NO SESSION")
                .font(Theme.TypeScale.label)
                .tracking(1.4)
                .foregroundStyle(Theme.secondaryText)
            Text("OPEN RESTLESS ON YOUR PHONE")
                .font(Theme.TypeScale.micro)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, 12)
    }

    private func phaseLabel(_ snapshot: SessionSnapshot) -> String {
        snapshot.phase == .done ? "SESSION COMPLETE" : snapshot.kicker
    }

    private func title(_ snapshot: SessionSnapshot, payload: WatchSessionPayload) -> String {
        snapshot.phase == .done ? snapshot.preset.name : payload.movementName(for: snapshot)
    }

    private func positionLabel(_ snapshot: SessionSnapshot) -> String? {
        if snapshot.phase == .done {
            return snapshot.subtitle
        }
        let text = snapshot.roundSetCopy.text
        return text.isEmpty ? nil : text
    }

    private func countLabel(_ snapshot: SessionSnapshot) -> String {
        "\(snapshot.doneSets) OF \(plural(snapshot.totalSets, "SET", "SETS"))"
    }
}

/// The completed-set count as segments, never as a clock. Long sessions keep
/// the same width by folding several sets into one segment.
struct WatchSetBar: View {
    let done: Int
    let total: Int
    let accent: Color

    private var slots: Int {
        min(max(total, 1), 24)
    }

    private var filled: Int {
        guard total > 0 else { return 0 }
        if total <= slots { return min(max(done, 0), slots) }
        let ratio = Double(done) / Double(total)
        return min(max(Int((ratio * Double(slots)).rounded()), 0), slots)
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<slots, id: \.self) { index in
                Capsule()
                    .fill(index < filled ? accent : Theme.hairline)
                    .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) sets")
    }
}
