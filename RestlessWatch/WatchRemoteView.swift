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

            WatchBlockBar(snapshot: snapshot)
                .padding(.top, 8)

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
}

/// The current block's completed sets as one continuous bar, never a clock.
/// Every block size uses the same form: the block count above, the block's bar,
/// then the session-wide count. The two numbers differ in a multi-block session,
/// which is why both labels are explicit.
struct WatchBlockBar: View {
    let snapshot: SessionSnapshot

    private var progress: BlockProgress { snapshot.blockProgress }

    private var blockCount: String {
        "\(progress.done) / \(progress.total)"
    }

    private var sessionCount: String {
        "\(snapshot.doneSets) OF \(plural(snapshot.totalSets, "SET", "SETS"))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(blockCount)
                    .font(.system(size: 26, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("SETS IN THIS BLOCK")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.hairline)

                    Capsule()
                        .fill(snapshot.accentColor)
                        .frame(width: proxy.size.width * progress.fraction)
                }
            }
            .frame(height: 8)

            Text(sessionCount)
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.6)
                .monospacedDigit()
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(progress.done) of \(progress.total) sets in this block, "
                + "\(snapshot.doneSets) of \(snapshot.totalSets) in the session"
        )
    }
}
