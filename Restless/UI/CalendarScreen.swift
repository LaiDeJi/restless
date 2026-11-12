import SwiftData
import SwiftUI

/// One visible month, stored as a year and a zero-based month so navigation
/// cannot drift with the day of the month.
struct CalendarMonth: Equatable {
    let year: Int
    let month: Int

    static func current(now: Date = .now, calendar: Calendar = .current) -> CalendarMonth {
        CalendarMonth(
            year: calendar.component(.year, from: now),
            month: calendar.component(.month, from: now) - 1
        )
    }

    func firstDay(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month + 1, day: 1)) ?? .now
    }

    func advanced(by months: Int, calendar: Calendar) -> CalendarMonth {
        guard let moved = calendar.date(
            byAdding: .month,
            value: months,
            to: firstDay(in: calendar)
        ) else { return self }
        return CalendarMonth(
            year: calendar.component(.year, from: moved),
            month: calendar.component(.month, from: moved) - 1
        )
    }
}

struct CalendarDaySelection: Identifiable, Hashable {
    let day: Date
    var id: Date { day }
}

/// One month cell: the date, its record or plan, and whether the filter dims it.
struct CalendarDayCell {
    let day: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    let isDimmed: Bool
    let mark: TrainingDayMark
    let records: [WorkoutRecord]
}

struct CalendarScreen: View {
    @Environment(AppRouter.self) private var router
    @Environment(CalendarSettingsModel.self) private var calendarSettings
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \PresetRecord.createdAt) private var presets: [PresetRecord]
    @Query(sort: \WorkoutRecord.startedAt) private var records: [WorkoutRecord]

    @State private var month = CalendarMonth.current()
    @State private var filter: UUID?
    @State private var selectedDay: CalendarDaySelection?
    @State private var now = Date.now

    private var calendar: Calendar { .current }
    private var orderedPresets: [PresetRecord] { PresetRepository.ordered(presets) }
    private var sessions: [RotationSession] {
        orderedPresets.map { RotationSession(id: $0.id, name: $0.name) }
    }

    private var rotation: TrainingRotation {
        TrainingRotation(
            settings: calendarSettings.settings,
            sessions: sessions,
            calendar: calendar
        )
    }

    private var recordsByDay: [Date: [WorkoutRecord]] {
        Dictionary(grouping: records) { calendar.startOfDay(for: $0.startDay) }
    }

    private var boundary: Date? {
        rotation.nextUnstartedDay(
            today: now,
            recordedDays: Set(recordsByDay.keys)
        )
    }

    private var gridDays: [Date] {
        let first = month.firstDay(in: calendar)
        let weekday = calendar.component(.weekday, from: first)
        let lead = (weekday - calendar.firstWeekday + 7) % 7
        guard let start = calendar.date(byAdding: .day, value: -lead, to: first) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                filters.padding(.top, 14)
                monthHeader.padding(.top, 20)
                weekdayRow.padding(.top, 12)
                grid.padding(.top, 6)
                upNextLine.padding(.top, 14)
                settingsSection.padding(.top, 22)
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(item: $selectedDay) { selection in
            daySheet(for: selection.day)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
        }
        .onAppear {
            now = .now
            prepareAnchor()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            now = .now
            prepareAnchor()
        }
        .onChange(of: orderedPresets.map(\.id)) { _, ids in
            if let filter, !ids.contains(filter) { self.filter = nil }
        }
    }

    // MARK: Header and filters

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("TRAINING")
                    .font(Theme.TypeScale.section)
                    .tracking(1.2)
                    .foregroundStyle(Theme.secondaryText)
                Text("CALENDAR")
                    .font(Theme.TypeScale.screenTitle)
                    .foregroundStyle(.white)
            }
            Spacer()
        }
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                filterChip("ALL", id: nil)
                ForEach(orderedPresets) { preset in
                    filterChip(preset.name.uppercased(), id: preset.id)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func filterChip(_ title: String, id: UUID?) -> some View {
        let selected = filter == id
        return Button {
            filter = id
        } label: {
            Text(title)
                .font(Theme.TypeScale.micro)
                .tracking(0.6)
                .foregroundStyle(selected ? Theme.ink : .white.opacity(0.42))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 12)
                .frame(minHeight: 32, maxHeight: 32)
                .frame(maxWidth: 160)
                .background(Capsule().fill(selected ? Theme.setAccent : .white.opacity(0.04)))
                .overlay(
                    Capsule().stroke(
                        selected ? .clear : .white.opacity(0.09),
                        lineWidth: 1
                    )
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Month

    private var monthHeader: some View {
        HStack(spacing: 10) {
            monthButton("chevron.left", label: "Previous month") {
                month = month.advanced(by: -1, calendar: calendar)
            }
            Text(month.firstDay(in: calendar)
                .formatted(.dateTime.month(.wide).year())
                .uppercased())
                .font(Theme.TypeScale.section.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.56))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
            monthButton("chevron.right", label: "Next month") {
                month = month.advanced(by: 1, calendar: calendar)
            }
        }
    }

    private func monthButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(Theme.TypeScale.meta.weight(.bold))
                .foregroundStyle(.white.opacity(0.62))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .chromeGlass(in: Circle(), fallbackFill: .white.opacity(0.04))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var weekdayRow: some View {
        let symbols = calendar.shortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { index in
                Text(symbols[(start + index) % 7].uppercased())
                    .font(Theme.TypeScale.micro)
                    .tracking(0.4)
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private var grid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 4), count: 7),
            spacing: 4
        ) {
            ForEach(gridDays, id: \.self) { day in
                cellView(cell(for: day))
            }
        }
    }

    private func cellView(_ cell: CalendarDayCell) -> some View {
        let content = CalendarCellView(cell: cell, calendar: calendar)
        return Group {
            if cell.isCurrentMonth {
                Button {
                    selectedDay = CalendarDaySelection(day: cell.day)
                } label: {
                    content
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(CalendarCellView.accessibilityText(cell, calendar: calendar)))
                .accessibilityHint(Text("Opens the day"))
            } else {
                content.accessibilityHidden(true)
            }
        }
    }

    private func cell(for day: Date) -> CalendarDayCell {
        let start = calendar.startOfDay(for: day)
        let dayRecords = recordsByDay[start] ?? []
        let plan = rotation.plan(for: start)
        let matches: Bool
        if let filter {
            if dayRecords.isEmpty {
                matches = plan?.id == filter
            } else {
                matches = dayRecords.contains { $0.presetID == filter }
            }
        } else {
            matches = true
        }
        return CalendarDayCell(
            day: start,
            isCurrentMonth: calendar.isDate(day, equalTo: month.firstDay(in: calendar), toGranularity: .month),
            isToday: calendar.isDateInToday(start),
            isDimmed: filter != nil && !matches,
            mark: rotation.mark(for: start, boundary: boundary),
            records: dayRecords
        )
    }

    // MARK: Up next

    private var upNextLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("UP NEXT")
                .font(Theme.TypeScale.micro)
                .tracking(1.0)
                .foregroundStyle(Theme.tertiaryText)
            if let boundary, let plan = rotation.plan(for: boundary) {
                Text("\(plan.name.uppercased()) · \(whenText(boundary))")
                    .font(Theme.TypeScale.meta.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text("NO TRAINING DAY")
                    .font(Theme.TypeScale.meta.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.055), lineWidth: 1)
        )
    }

    private func whenText(_ day: Date) -> String {
        if calendar.isDateInToday(day) { return "TODAY" }
        if calendar.isDateInTomorrow(day) { return "TOMORROW" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased()
    }

    // MARK: Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SETTINGS")
                .font(Theme.TypeScale.section.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Theme.secondaryText)
                .padding(.bottom, 2)
            restGapRow
            settingsRow(
                "EXCEPTIONS",
                value: CalendarCopy.exceptionsSummary(
                    calendarSettings.settings.exceptions,
                    calendar: calendar
                )
            ) {
                router.calendarPath.append(.exceptions)
            }
        }
    }

    private var restGapRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("REST DAYS")
                    .font(Theme.TypeScale.micro)
                    .tracking(1.0)
                    .foregroundStyle(Theme.secondaryText)
                Text(CalendarCopy.restGapRowValue)
                    .font(Theme.TypeScale.meta.weight(.semibold))
                    .tracking(0.2)
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            HStack(spacing: 2) {
                gapButton(
                    "minus",
                    label: "One rest day fewer",
                    delta: -1,
                    disabled: calendarSettings.settings.restDaysBetween == 0
                )
                Text("\(calendarSettings.settings.restDaysBetween)")
                    .font(Theme.TypeScale.value.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 22)
                    .accessibilityLabel(Text("\(calendarSettings.settings.restDaysBetween) rest days"))
                gapButton(
                    "plus",
                    label: "One rest day more",
                    delta: 1,
                    disabled: calendarSettings.settings.restDaysBetween == CalendarSettings.maxRestDaysBetween
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.055), lineWidth: 1)
        )
    }

    private func gapButton(
        _ systemName: String,
        label: String,
        delta: Int,
        disabled: Bool
    ) -> some View {
        Button {
            calendarSettings.setRestGap(calendarSettings.settings.restDaysBetween + delta)
        } label: {
            Image(systemName: systemName)
                .font(Theme.TypeScale.body.weight(.semibold))
                .foregroundStyle(.white.opacity(disabled ? 0.24 : 0.72))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .background(Circle().fill(.white.opacity(0.04)))
                .overlay(Circle().stroke(.white.opacity(0.09), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .disabled(disabled)
    }

    private func settingsRow(_ label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(Theme.TypeScale.micro)
                        .tracking(1.0)
                        .foregroundStyle(Theme.secondaryText)
                    Text(value)
                        .font(Theme.TypeScale.meta.weight(.semibold))
                        .tracking(0.2)
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(Theme.TypeScale.body.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.055), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func prepareAnchor() {
        calendarSettings.initializeRotation(today: now)
    }

    private func daySheet(for day: Date) -> CalendarDaySheet {
        let start = calendar.startOfDay(for: day)
        return CalendarDaySheet(
            day: start,
            records: recordsByDay[start] ?? [],
            recordedDays: Set(recordsByDay.keys),
            orderedPresets: orderedPresets.map(\.preset)
        )
    }
}
