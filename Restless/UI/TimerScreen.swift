import SwiftData
import SwiftUI

struct TimerScreen: View {
    @Environment(SessionEngine.self) private var engine
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \MovementRecord.createdAt) private var movements: [MovementRecord]

    @ScaledMetric(relativeTo: .largeTitle) private var largeCountdown: CGFloat = 78
    @ScaledMetric(relativeTo: .largeTitle) private var smallCountdown: CGFloat = 52
    @State private var showingRestartConfirmation = false
    @State private var celebrating = false
    @State private var pendingCompletion = false
    @State private var lastSeenCompletion = 0
    @State private var celebrationTask: Task<Void, Never>?

    var body: some View {
        let snapshot = engine.snapshot

        ZStack {
            background(snapshot)

            GeometryReader { proxy in
                ScrollView {
                    TimerStageLayout(
                        viewportHeight: proxy.size.height,
                        heroSide: heroSide(proxy.size)
                    ) {
                        header(snapshot)
                            .timerStageRole(.header)

                        if snapshot.preset.blocks.count > 1 {
                            blockStrip(snapshot)
                                .padding(.top, 2)
                                .timerStageRole(.blockStrip)
                        }

                        positionStrip(snapshot)
                            .timerStageRole(.positionStrip)

                        hero(snapshot, side: heroSide(proxy.size))
                            .timerStageRole(.hero)

                        SetMap(snapshot: snapshot)
                            .timerStageRole(.map)

                        actions(snapshot)
                            .timerStageRole(.actions)
                    }
                    .padding(.horizontal, 22)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }

            if celebrating {
                SessionCelebration()
                    .zIndex(1)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.4), value: snapshot.phase)
        .animation(.easeInOut(duration: 0.4), value: snapshot.restKind)
        .onAppear {
            syncCompletionEvent()
            startPendingCelebration()
        }
        .onChange(of: engine.completionEvent) { _, _ in
            syncCompletionEvent()
        }
        .onChange(of: router.tab) { _, tab in
            if tab == .timer {
                syncCompletionEvent()
                startPendingCelebration()
            } else {
                pauseCelebration()
            }
        }
        .onChange(of: snapshot.phase) { _, phase in
            if phase != .done { stopCelebration() }
        }
        .onChange(of: snapshot.phase) { _, _ in
            showingRestartConfirmation = false
        }
        .onChange(of: snapshot.canRestart) { _, canRestart in
            if !canRestart { showingRestartConfirmation = false }
        }
        .onChange(of: router.tab) { _, tab in
            if tab != .timer { showingRestartConfirmation = false }
        }
        .alert("Restart this session?", isPresented: $showingRestartConfirmation) {
            Button("Restart Session", role: .destructive) {
                engine.perform(.restart)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears all completed sets, cancels the current rest, and returns to block 1, set 1.")
        }
    }

    // MARK: Background

    private func background(_ snapshot: SessionSnapshot) -> some View {
        ZStack {
            snapshot.surfaceColor
            RadialGradient(
                colors: [snapshot.accentColor.opacity(0.075), .clear],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 0,
                endRadius: 230
            )
        }
        .ignoresSafeArea()
    }

    // MARK: Header

    private func header(_ snapshot: SessionSnapshot) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                sessionLabel(snapshot)
                Spacer(minLength: 8)
                headerControls(snapshot)
            }

            VStack(alignment: .trailing, spacing: 6) {
                sessionLabel(snapshot)
                    .frame(maxWidth: .infinity, alignment: .leading)
                headerControls(snapshot)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 44)
    }

    /// EDIT stays hidden while locked; RESTART is a session action and stays
    /// available through a set or rest once a set is done.
    @ViewBuilder
    private func headerControls(_ snapshot: SessionSnapshot) -> some View {
        if !snapshot.isLocked || snapshot.canRestart {
            HStack(spacing: 8) {
                if !snapshot.isLocked {
                    editButton(snapshot)
                }
                if snapshot.canRestart {
                    restartButton(snapshot)
                }
            }
        }
    }

    private func sessionLabel(_ snapshot: SessionSnapshot) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(snapshot.accentColor)
                .frame(width: 7, height: 7)
                .shadow(color: snapshot.accentColor.opacity(0.7), radius: 4)

            Text(snapshot.preset.name.uppercased())
                .font(Theme.TypeScale.section)
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private func editButton(_ snapshot: SessionSnapshot) -> some View {
        Button {
            router.openActiveSession(snapshot.preset.id)
        } label: {
            Text("EDIT")
                .font(Theme.TypeScale.compactAction)
                .tracking(0.9)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .contentShape(Capsule())
                .chromeGlass(in: Capsule(), fallbackFill: .white.opacity(0.08))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit session")
    }

    /// Restart is one session action with one consequence; the confirmation
    /// names it before any progress is cleared.
    private func restartButton(_ snapshot: SessionSnapshot) -> some View {
        Button {
            showingRestartConfirmation = true
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .chromeGlass(
                    in: Capsule(),
                    fallbackFill: .white.opacity(0.08),
                    fallbackStroke: .white.opacity(0.12)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Restart session")
    }

    // MARK: Blocks

    private func blockStrip(_ snapshot: SessionSnapshot) -> some View {
        let blocks = snapshot.preset.blocks
        let activeIndex = snapshot.position.blockIndex
        let done = snapshot.phase == .done

        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                        let complete = done || snapshot.doneSets >= blockOffset(index, in: blocks) + block.totalSets
                        let active = !done && index == activeIndex

                        HStack(spacing: 5) {
                            if complete {
                                Image(systemName: "checkmark")
                                    .font(Theme.TypeScale.label.weight(.bold))
                            }
                            Text(block.name.uppercased())
                                .font(Theme.TypeScale.label.weight(.bold))
                                .tracking(0.8)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .foregroundStyle(active ? Theme.ink : .white.opacity(complete ? 0.4 : 0.62))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(minHeight: 32)
                        .background(
                            Capsule().fill(active ? snapshot.accentColor : .white.opacity(complete ? 0.035 : 0.02))
                        )
                        .overlay(
                            Capsule().stroke(active ? .clear : .white.opacity(0.09), lineWidth: 1)
                        )
                        .id(index)
                        .accessibilityLabel(
                            "Block \(index + 1) of \(blocks.count), \(block.name), \(complete ? "complete" : active ? "active" : "upcoming")"
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear { proxy.scrollTo(activeIndex, anchor: .center) }
            .onChange(of: activeIndex) { _, index in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }

    private func blockOffset(_ index: Int, in blocks: [WorkoutBlock]) -> Int {
        blocks.prefix(index).reduce(0) { safeSum($0, $1.totalSets) }
    }

    // MARK: Position

    @ViewBuilder
    private func positionStrip(_ snapshot: SessionSnapshot) -> some View {
        if snapshot.phase == .done {
            Text("SESSION COMPLETE")
                .font(Theme.TypeScale.label.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(snapshot.accentColor)
                .frame(minHeight: 24)
        } else {
            TimerPositionStrip(
                snapshot: snapshot,
                movementName: movementName(snapshot.currentBlockMovement?.movementId)
            )
        }
    }

    // MARK: Hero

    private func heroSide(_ size: CGSize) -> CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return min(340, size.width - 44)
        }
        return min(320, size.width - 44, size.height * 0.42)
    }

    private func hero(_ snapshot: SessionSnapshot, side: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.065), lineWidth: 13)

            if snapshot.isResting || snapshot.isPerforming {
                TimelineView(.periodic(from: .now, by: 1.0 / 20.0)) { context in
                    Circle()
                        .trim(from: 0, to: snapshot.progress(at: context.date))
                        .stroke(snapshot.accentColor, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: snapshot.accentColor.opacity(0.35), radius: 9)
                }
            } else if snapshot.phase == .done {
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(snapshot.accentColor, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: snapshot.accentColor.opacity(0.28), radius: 9)
            }

            VStack(spacing: 0) {
                Text(snapshot.kicker)
                    .font(Theme.TypeScale.label.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(snapshot.accentColor)
                    .contentTransition(.opacity)

                heroTime(snapshot)
                    .padding(.top, 8)
                    .contentTransition(.numericText())

                Text(subtitle(snapshot))
                    .font(Theme.TypeScale.meta.weight(.medium))
                    .tracking(0.4)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 12)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 34)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: side, height: side)
    }

    @ViewBuilder
    private func heroTime(_ snapshot: SessionSnapshot) -> some View {
        let size = countdownSize(snapshot)

        Group {
            switch snapshot.phase {
            case .notStarted:
                Text("START")
            case .resting:
                if let deadline = snapshot.deadline, deadline > .now {
                    Text(timerInterval: Date.now...deadline, countsDown: true)
                } else {
                    Text(clockString(snapshot.secondsRemainingNow))
                }
            case .performing:
                if let deadline = snapshot.setDeadline, deadline > .now {
                    Text(timerInterval: Date.now...deadline, countsDown: true)
                } else {
                    Text(clockString(snapshot.secondsRemainingSetNow))
                }
            case .paused:
                Text(clockString(snapshot.pausedRemaining))
            case .ready:
                if let rest = snapshot.upcomingRest {
                    if rest.isZero {
                        Text("NEXT")
                    } else {
                        Text(clockString(rest.duration))
                    }
                } else {
                    Text("FINISH")
                }
            case .done:
                Text("DONE")
            }
        }
        .font(.system(size: size, weight: .semibold))
        .kerning(snapshot.usesSmallHero ? 0.5 : -size * 0.05)
        .monospacedDigit()
        .foregroundStyle(.white)
        .lineLimit(1)
    }

    private func countdownSize(_ snapshot: SessionSnapshot) -> CGFloat {
        snapshot.usesSmallHero ? min(smallCountdown, 68) : min(largeCountdown, 96)
    }

    // MARK: Actions

    private func actions(_ snapshot: SessionSnapshot) -> some View {
        HStack(spacing: 9) {
            Button {
                engine.perform(snapshot.primaryAction)
            } label: {
                VStack(spacing: 2) {
                    Text(snapshot.primaryTitle)
                        .font(Theme.TypeScale.action)
                        .tracking(0.6)
                    Text(snapshot.primarySubtitle)
                        .font(Theme.TypeScale.meta.weight(.semibold))
                        .tracking(0.2)
                        .opacity(0.55)
                }
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 62)
                .background(Capsule().fill(snapshot.accentColor))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            if snapshot.isResting {
                Button {
                    engine.perform(.skipRest)
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(Theme.TypeScale.action)
                        .foregroundStyle(.white)
                        .frame(width: 62, height: 62)
                        .background(Circle().fill(.white.opacity(0.07)))
                        .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip rest")
            }
        }
    }

    // MARK: Celebration

    /// The event counter is view state, so the first count this view sees must
    /// not celebrate: a restored done session starts at zero. A newer count on
    /// appear means the completion happened while another tab was showing.
    private func syncCompletionEvent() {
        let event = engine.completionEvent
        guard event != lastSeenCompletion else { return }
        lastSeenCompletion = event
        guard router.tab == .timer else {
            pendingCompletion = true
            return
        }
        startCelebration()
    }

    private func startPendingCelebration() {
        guard pendingCompletion, router.tab == .timer else { return }
        startCelebration()
    }

    private func startCelebration() {
        guard engine.snapshot.phase == .done else { return }
        pendingCompletion = false
        celebrationTask?.cancel()
        celebrating = true
        celebrationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(SessionCelebration.lifetime))
            guard !Task.isCancelled else { return }
            celebrating = false
        }
    }

    private func stopCelebration() {
        pauseCelebration()
        pendingCompletion = false
    }

    /// Leaving TIMER drops the effect but keeps a completion that still owes a
    /// celebration for the next visit.
    private func pauseCelebration() {
        celebrationTask?.cancel()
        celebrationTask = nil
        celebrating = false
    }

    // MARK: Names

    private func subtitle(_ snapshot: SessionSnapshot) -> String {
        guard snapshot.isResting else { return snapshot.subtitle }
        return snapshot.restContext { movementName($0) }
    }

    private var movementNames: [UUID: String] {
        Dictionary(movements.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private func movementName(_ id: UUID?) -> String {
        guard let id else { return "Missing movement" }
        return movementNames[id] ?? "Missing movement"
    }
}
