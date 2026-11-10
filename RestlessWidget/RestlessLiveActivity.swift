import ActivityKit
import SwiftUI
import WidgetKit

struct RestlessLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestlessActivityAttributes.self) { context in
            LockScreenPanel(context: context)
                .activityBackgroundTint(Theme.background)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let snapshot = context.attributes.snapshot(context.state)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(snapshot.kicker)
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(snapshot.accentColor)
                        Text(blockLabel(context))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(movementLabel(context))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if !snapshot.isResting {
                            Text(positionLabel(context))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.45))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    TimerText(context: context)
                        .font(.system(size: 30, weight: .semibold))
                        .monospacedDigit()
                        .padding(.trailing, 6)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        if let rest = restLine(context) {
                            Text(rest)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }

                        RestProgressBar(context: context)

                        ActivityButtons(context: context)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
                }
            } compactLeading: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(snapshot.accentColor)
                        .frame(width: 6, height: 6)
                    Text(compactLabel(context))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } compactTrailing: {
                CompactTimerText(context: context)
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(snapshot.accentColor)
            } minimal: {
                CompactTimerText(context: context)
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(snapshot.accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .allowsTightening(true)
            }
            .widgetURL(URL(string: "restless://session"))
            .keylineTint(snapshot.accentColor)
        }
    }
}

// MARK: - Copy

/// The active block, or `DONE` once the whole session is finished.
private func blockLabel(_ context: ActivityViewContext<RestlessActivityAttributes>) -> String {
    let snapshot = context.attributes.snapshot(context.state)
    return snapshot.phase == .done ? "DONE" : snapshot.currentBlock.name.uppercased()
}

/// The active movement. The widget has no library, so the names travel in the
/// activity attributes.
private func movementLabel(_ context: ActivityViewContext<RestlessActivityAttributes>) -> String {
    let snapshot = context.attributes.snapshot(context.state)
    guard snapshot.phase != .done else {
        return "\(snapshot.doneSets) OF \(plural(snapshot.totalSets, "SET", "SETS"))"
    }
    return context.attributes.movementName(snapshot.position.movementId)
}

/// `ROUND 2 OF 4 · SET 3 OF 4`, or only the segment that is not 1.
private func positionLabel(_ context: ActivityViewContext<RestlessActivityAttributes>) -> String {
    let snapshot = context.attributes.snapshot(context.state)
    guard snapshot.phase != .done else { return "SESSION COMPLETE" }
    return snapshot.roundSetCopy.text
}

/// The expanded island's rest line: what just finished, shown full width above
/// the progress bar. A movement switch reads `AFTER BICEPS · NEXT TRICEPS`
/// under the round-rest kicker. Nil outside a rest.
private func restLine(_ context: ActivityViewContext<RestlessActivityAttributes>) -> String? {
    let snapshot = context.attributes.snapshot(context.state)
    guard snapshot.isResting else { return nil }
    let copy = restCopy(context)
    return copy.isEmpty ? nil : copy
}

/// The rest subtitle names the finished movement or block and what follows.
/// `SessionSnapshot` has no library, so this copy resolves the names here.
private func restCopy(_ context: ActivityViewContext<RestlessActivityAttributes>) -> String {
    let snapshot = context.attributes.snapshot(context.state)
    guard snapshot.restTransition != nil else { return snapshot.subtitle }
    let copy = snapshot.restContext { context.attributes.movementName($0) }
    return copy.isEmpty ? snapshot.subtitle : copy
}

/// `CUR` for Curl, `DONE` when the whole session is finished.
private func compactLabel(_ context: ActivityViewContext<RestlessActivityAttributes>) -> String {
    let snapshot = context.attributes.snapshot(context.state)
    switch snapshot.phase {
    case .notStarted: return "READY"
    case .done: return "DONE"
    case .paused: return "PAUSED"
    case .ready, .performing, .resting:
        let name = context.attributes.movementName(snapshot.position.movementId)
        return String(name.prefix(3))
    }
}

// MARK: - Lock screen

private struct LockScreenPanel: View {
    let context: ActivityViewContext<RestlessActivityAttributes>

    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 26

    private var snapshot: SessionSnapshot {
        context.attributes.snapshot(context.state)
    }

    var body: some View {
        let state = stateRow(context)

        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.preset.name.uppercased())
                        .font(Theme.TypeScale.micro)
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)

                    Text(snapshot.phase == .done ? "SESSION COMPLETE" : movementLabel(context))
                        .font(Theme.TypeScale.rowTitle)
                        .tracking(0.2)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TimerText(context: context)
                    .font(.system(size: min(timerSize, 32), weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(state.kicker)
                    .foregroundStyle(snapshot.accentColor)
                Text("·")
                    .foregroundStyle(.white.opacity(0.3))
                Text(state.context)
                    .foregroundStyle(.white.opacity(0.62))
                    .minimumScaleFactor(0.75)
            }
            .font(Theme.TypeScale.label.weight(.semibold))
            .tracking(1.0)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            if snapshot.isResting || snapshot.isPerforming {
                PanelProgressBar(context: context)
            }

            ActivityButtons(context: context)
        }
        .padding(14)
        .dynamicTypeSize(...(.xxLarge))
    }
}

/// The panel's one state row: the phase kicker and one context string. Ready
/// names the upcoming set or round; a rest and a paused rest name what just
/// finished; a timed set names the rest that follows; done carries the totals.
private func stateRow(
    _ context: ActivityViewContext<RestlessActivityAttributes>
) -> (kicker: String, context: String) {
    let snapshot = context.attributes.snapshot(context.state)

    switch snapshot.phase {
    case .notStarted:
        return (snapshot.kicker, snapshot.subtitle)
    case .ready:
        return (snapshot.kicker, readyContext(snapshot))
    case .performing:
        return ("WORK", snapshot.subtitle)
    case .resting, .paused:
        let copy = restCopy(context)
        return (snapshot.kicker, copy.isEmpty ? snapshot.subtitle : copy)
    case .done:
        return (snapshot.kicker, snapshot.subtitle)
    }
}

private func readyContext(_ snapshot: SessionSnapshot) -> String {
    let block = snapshot.currentBlock
    let position = snapshot.position
    let copy = position.roundSetCopy(in: block)
    if copy.roundText != nil, block.setsPerRound == 1 {
        return "ROUND \(position.round) OF \(max(block.rounds, 1))"
    }
    if copy.setText != nil {
        return "SET \(position.set) OF \(max(block.setsPerRound, 1))"
    }
    return "AFTER THIS SET"
}

/// The panel's own 4 pt progress bar. `ProgressView(timerInterval:)` reserves a
/// label row even with its labels hidden, which pushes the panel past its
/// 160-point budget at xxLarge.
private struct PanelProgressBar: View {
    let context: ActivityViewContext<RestlessActivityAttributes>

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = context.attributes.snapshot(context.state)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.14))
                    Capsule()
                        .fill(snapshot.accentColor)
                        .frame(width: max(0, proxy.size.width * snapshot.progress(at: timeline.date)))
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Pieces

private struct TimerText: View {
    let context: ActivityViewContext<RestlessActivityAttributes>

    private var snapshot: SessionSnapshot {
        context.attributes.snapshot(context.state)
    }

    var body: some View {
        switch snapshot.phase {
        case .notStarted:
            Text("START")
        case .resting:
            if let deadline = snapshot.deadline {
                Text(timerInterval: Date.now...deadline, countsDown: true)
            } else {
                Text(clockString(snapshot.duration))
            }
        case .performing:
            if let deadline = snapshot.setDeadline {
                Text(timerInterval: Date.now...deadline, countsDown: true)
            } else {
                Text(clockString(snapshot.secondsRemainingSetNow))
            }
        case .paused:
            Text(clockString(snapshot.pausedRemaining))
        case .ready:
            if let rest = snapshot.upcomingRest, !rest.isZero {
                Text(clockString(rest.duration))
            } else {
                Text(snapshot.upcomingRest == nil ? "FINISH" : "NEXT")
            }
        case .done:
            Text("DONE")
        }
    }
}

private struct CompactTimerText: View {
    let context: ActivityViewContext<RestlessActivityAttributes>

    private var snapshot: SessionSnapshot {
        context.attributes.snapshot(context.state)
    }

    var body: some View {
        switch snapshot.phase {
        case .notStarted:
            Text("READY")
        case .resting:
            if let deadline = snapshot.deadline {
                Text(timerInterval: Date.now...deadline, countsDown: true)
            } else {
                Text(clockString(snapshot.duration))
            }
        case .performing:
            if let deadline = snapshot.setDeadline {
                Text(timerInterval: Date.now...deadline, countsDown: true)
            } else {
                Text(clockString(snapshot.secondsRemainingSetNow))
            }
        case .paused:
            Text(clockString(snapshot.pausedRemaining))
        case .ready:
            Text("READY")
        case .done:
            Text("DONE")
        }
    }
}

private struct RestProgressBar: View {
    let context: ActivityViewContext<RestlessActivityAttributes>

    private var snapshot: SessionSnapshot {
        context.attributes.snapshot(context.state)
    }

    var body: some View {
        Group {
            switch snapshot.phase {
            case .resting:
                if let deadline = snapshot.deadline {
                    ProgressView(timerInterval: Date.now...deadline, countsDown: true)
                } else {
                    ProgressView(value: 0)
                }
            case .performing:
                ProgressView(value: snapshot.setProgress(at: .now))
            case .paused:
                ProgressView(value: pausedFraction)
            default:
                EmptyView()
            }
        }
        .tint(snapshot.accentColor)
    }

    private var pausedFraction: Double {
        guard snapshot.duration > 0 else { return 0 }
        return 1 - Double(snapshot.pausedRemaining) / Double(snapshot.duration)
    }
}

private struct ActivityButtons: View {
    let context: ActivityViewContext<RestlessActivityAttributes>

    private var snapshot: SessionSnapshot {
        context.attributes.snapshot(context.state)
    }

    var body: some View {
        Group {
            switch snapshot.phase {
            case .notStarted:
                ActivityLink("START SESSION", route: "start-session")
            case .ready:
                if snapshot.currentBlockMovement?.endCondition == .time {
                    ActivityLink("START", route: "start-set")
                } else {
                    ActivityLink(
                        snapshot.upcomingRest == nil ? "FINISH" : "SET DONE",
                        route: "set-done"
                    )
                }
            case .performing:
                ActivityLink("SET DONE", route: "set-done")
            case .resting:
                HStack(spacing: 8) {
                    ActivityLink("PAUSE", route: "pause")
                    ActivityLink("SKIP", route: "skip")
                }
            case .paused:
                HStack(spacing: 8) {
                    ActivityLink("RESUME", route: "resume")
                    ActivityLink("SKIP", route: "skip")
                }
            case .done:
                ActivityLink("START AGAIN", route: "restart")
            }
        }
        .tint(snapshot.accentColor)
    }
}

/// A Live Activity button can only change the session by opening the app on a
/// personal team, where App Groups are unavailable.
private struct ActivityLink: View {
    let title: String
    let route: String

    init(_ title: String, route: String) {
        self.title = title
        self.route = route
    }

    var body: some View {
        Link(destination: URL(string: "restless://\(route)")!) {
            Text(title)
                .font(Theme.TypeScale.compactAction.weight(.bold))
                .tracking(0.5)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 32)
                .background(Capsule().fill(.white.opacity(0.14)))
        }
    }
}
