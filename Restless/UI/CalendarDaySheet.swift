import SwiftData
import SwiftUI

/// A day's sheet. It leads with what the date is and the action, then the
/// detail: a planned day offers START and a footer of CHANGE, SKIP and NEW
/// ROUND; a skipped day swaps in UNSKIP; a recorded day is read-only with a
/// two-tap DELETE RECORD and NEW ROUND; a rest day offers only NEW ROUND; a
/// closed day offers nothing; every day without START shows NEXT.
struct CalendarDaySheet: View {
    let day: Date
    let records: [WorkoutRecord]
    let recordedDays: Set<Date>
    let orderedPresets: [WorkoutPreset]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SessionEngine.self) private var engine
    @Environment(AppRouter.self) private var router
    @Environment(CalendarSettingsModel.self) private var calendarSettings

    @State private var armedRunKey: String?
    @State private var showingOverwrite = false
    @State private var showingPicker = false

    private var calendar: Calendar { .current }

    private var rotation: TrainingRotation {
        TrainingRotation(
            settings: calendarSettings.settings,
            sessions: orderedPresets.map { RotationSession(id: $0.id, name: $0.name) },
            calendar: calendar
        )
    }

    private var boundary: Date? {
        rotation.nextUnstartedDay(today: .now, recordedDays: recordedDays)
    }

    private var mark: TrainingDayMark {
        rotation.mark(for: day, boundary: boundary)
    }

    private var plannedSession: RotationSession? {
        rotation.plannedSession(for: day)
    }

    private var planPreset: WorkoutPreset? {
        guard let plannedSession else { return nil }
        return orderedPresets.first { $0.id == plannedSession.id }
    }

    private var scheduledPreset: WorkoutPreset? {
        guard let scheduled = rotation.scheduledPlan(for: day) else { return nil }
        return orderedPresets.first { $0.id == scheduled.id }
    }

    private var isChanged: Bool { rotation.isChanged(day) }
    private var isTodayOrLater: Bool {
        calendar.startOfDay(for: day) >= calendar.startOfDay(for: .now)
    }
    private var isOpen: Bool {
        !calendarSettings.settings.isClosed(day, calendar: calendar)
    }
    private var latestRecord: WorkoutRecord? {
        records.max { $0.startedAt < $1.startedAt }
    }

    /// The next planned session after the date, skipping rest, closed and
    /// skipped days.
    private var next: (day: Date, preset: WorkoutPreset)? {
        for offset in 1..<366 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: day) else {
                return nil
            }
            let target = calendar.startOfDay(for: candidate)
            guard let plan = rotation.plan(for: target) else { continue }
            guard let preset = orderedPresets.first(where: { $0.id == plan.id }) else { continue }
            return (target, preset)
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(CalendarCopy.longDay(day))
                    .font(Theme.TypeScale.section.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                titleRow

                if records.isEmpty {
                    emptyDayContent
                } else {
                    recordedContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .alert("Start \(planPreset?.name ?? "session")?", isPresented: $showingOverwrite) {
            Button("Start", role: .destructive) {
                if let planPreset { activate(planPreset) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(overwriteMessage)
        }
        .sheet(isPresented: $showingPicker) {
            CalendarChangePicker(
                day: day,
                presets: orderedPresets,
                scheduledPresetID: scheduledPreset?.id,
                chosenPresetID: planPreset?.id,
                onPick: choose,
                onDone: { showingPicker = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.background)
        }
    }

    // MARK: Title

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(Theme.TypeScale.pageTitle)
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if let tag {
                tagView(tag.text, tint: tag.tint)
            }
            Spacer(minLength: 0)
        }
    }

    private var title: String {
        if !records.isEmpty {
            return latestRecord?.sessionName ?? "RECORDED"
        }
        switch mark {
        case .planned(let session): return session.name
        case .skipped: return plannedSession?.name ?? "SKIPPED"
        case .rest: return "REST DAY"
        case .closed(let label): return label.isEmpty ? "CLOSED" : label.uppercased()
        case .none: return "NO RECORD"
        }
    }

    private var tag: (text: String, tint: Color)? {
        if !records.isEmpty { return ("RECORDED", Theme.setAccent) }
        switch mark {
        case .planned where isChanged: return ("CHANGED", Theme.roundAccent)
        case .skipped: return ("SKIPPED", Theme.secondaryText)
        case .planned, .rest, .closed, .none: return nil
        }
    }

    private func tagView(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(Theme.TypeScale.micro.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.12)))
            .overlay(Capsule().stroke(tint.opacity(0.34), lineWidth: 1))
    }

    // MARK: Content

    @ViewBuilder
    private var emptyDayContent: some View {
        switch mark {
        case .planned:
            if let planPreset {
                plannedContent(planPreset)
            } else {
                noPlanContent
            }
        case .skipped:
            if let planPreset {
                Text(CalendarCopy.sessionSummary(planPreset))
                    .font(Theme.TypeScale.body)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            note("This session is skipped. The gap, the anchor and every other day stay where they are.")
            nextLine
            footer(skippedActions)
        case .rest:
            Text(CalendarCopy.gapSummary(calendarSettings.settings.restDaysBetween))
                .font(Theme.TypeScale.body)
                .foregroundStyle(Theme.secondaryText)
            note("No session is planned on a rest day.")
            nextLine
            roundFooter
        case .closed(let label):
            Text(label.isEmpty ? "NO SESSION IS PLANNED" : label.uppercased() + " · NO SESSION IS PLANNED")
                .font(Theme.TypeScale.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            note("This date is closed. It skips that session's place in the round and does not move the schedule.")
            nextLine
        case .none:
            Text("This date is before the next planned session.")
                .font(Theme.TypeScale.body)
                .foregroundStyle(Theme.secondaryText)
            nextLine
            roundFooter
        }
    }

    private func plannedContent(_ preset: WorkoutPreset) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(CalendarCopy.sessionSummary(preset))
                .font(Theme.TypeScale.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                start(preset)
            } label: {
                Text("START")
                    .font(Theme.TypeScale.action)
                    .tracking(0.6)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(Capsule().fill(Theme.setAccent))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Activates this session and opens the timer at the start gate"))

            blockList(preset)

            footer([
                ("CHANGE", { showingPicker = true }),
                ("SKIP", skip),
                ("NEW ROUND", newRound)
            ])
        }
    }

    private var noPlanContent: some View {
        Text("This session is no longer saved.")
            .font(Theme.TypeScale.body)
            .foregroundStyle(Theme.secondaryText)
    }

    private var recordedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if records.count > 1 {
                Text(plural(records.count, "RECORD", "RECORDS"))
                    .font(Theme.TypeScale.micro.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.secondaryText)
            }
            ForEach(records) { record in
                CalendarRecordCard(record: record)
            }
            if case .closed = mark {
                note("CLOSED · THIS DATE STILL SHOWS ITS RECORD.")
            } else if case .skipped = mark {
                note("SKIPPED · THIS DATE STILL SHOWS ITS RECORD.")
            } else if case .rest = mark {
                note("REST DAY · THIS DATE STILL SHOWS ITS RECORD.")
            }
            nextLine
            footer(recordedActions)
        }
    }

    private var recordedActions: [(String, () -> Void)] {
        var actions: [(String, () -> Void)] = []
        if let latestRecord {
            let title = armedRunKey == latestRecord.runKey ? "TAP AGAIN TO DELETE" : "DELETE RECORD"
            actions.append((title, { delete(latestRecord) }))
        }
        if isTodayOrLater {
            actions.append(("NEW ROUND", newRound))
        }
        return actions
    }

    private var skippedActions: [(String, () -> Void)] {
        var actions: [(String, () -> Void)] = [("UNSKIP", unskip)]
        if isTodayOrLater {
            actions.append(("NEW ROUND", newRound))
        }
        return actions
    }

    private func blockList(_ preset: WorkoutPreset) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(preset.blocks) { block in
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.name)
                        .font(Theme.TypeScale.meta.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                    Text(blockNumbers(block))
                        .font(Theme.TypeScale.micro)
                        .foregroundStyle(Theme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(CalendarCopy.blockRestSummary(block))
                        .font(Theme.TypeScale.micro)
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.035))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.055), lineWidth: 1)
                )
            }
        }
    }

    // MARK: Footer

    @ViewBuilder
    private var roundFooter: some View {
        if isTodayOrLater {
            footer([("NEW ROUND", newRound)])
        }
    }

    @ViewBuilder
    private func footer(_ actions: [(String, () -> Void)]) -> some View {
        if !actions.isEmpty {
            CalendarActionFooter(actions: actions)
        }
    }

    private var nextLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("NEXT")
                .font(Theme.TypeScale.micro.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(Theme.tertiaryText)
            if let next {
                Text(CalendarCopy.nextSummary(
                    RotationSession(id: next.preset.id, name: next.preset.name),
                    day: next.day,
                    calendar: calendar
                ))
                .font(Theme.TypeScale.meta.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .truncationMode(.tail)
            } else {
                Text("NO SESSION PLANNED")
                    .font(Theme.TypeScale.meta.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Theme.TypeScale.meta)
            .foregroundStyle(Theme.secondaryText)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.roundAccent.opacity(0.07))
            )
    }

    // MARK: Change picker

    private func choose(_ preset: WorkoutPreset) {
        if scheduledPreset?.id == preset.id {
            calendarSettings.clearDayChange(day: day)
        } else {
            calendarSettings.setDayChange(day: day, presetID: preset.id)
        }
        showingPicker = false
    }

    // MARK: Actions

    private func skip() {
        calendarSettings.skip(day, sessions: rotation.sessions)
    }

    private func unskip() {
        calendarSettings.unskip(day)
    }

    private func newRound() {
        guard isOpen else { return }
        calendarSettings.startNewRound(on: day, today: .now)
    }

    private var overwriteMessage: String {
        let current = engine.snapshot.preset.name
        let sets = engine.snapshot.doneSets
        let target = planPreset?.name ?? "another session"
        if sets > 0 {
            return "\(current) has \(plural(sets, "completed set", "completed sets")). "
                + "Starting \(target) clears them and opens the start gate."
        }
        return "\(current) is still running. Starting \(target) clears it and opens the start gate."
    }

    private func start(_ preset: WorkoutPreset) {
        if engine.snapshot.doneSets > 0 || engine.snapshot.isLocked {
            showingOverwrite = true
        } else {
            activate(preset)
        }
    }

    private func activate(_ preset: WorkoutPreset) {
        ActivePresetStore.activate(id: preset.id, on: .now)
        engine.use(preset)
        dismiss()
        router.showTimer()
    }

    private func delete(_ record: WorkoutRecord) {
        guard armedRunKey == record.runKey else {
            armedRunKey = record.runKey
            return
        }
        WorkoutRepository.delete(runKey: record.runKey, in: context)
        dismiss()
    }
}
