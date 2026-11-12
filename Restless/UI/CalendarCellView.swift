import SwiftUI

/// The month cell: the day number, the record code or plan code, a set bar, and
/// a word for a rest, skipped or closed day. The whole cell is the hit target.
struct CalendarCellView: View {
    let cell: CalendarDayCell
    let calendar: Calendar

    private var latest: WorkoutRecord? {
        cell.records.max { $0.startedAt < $1.startedAt }
    }

    private var plan: RotationSession? {
        if case .planned(let session) = cell.mark { return session }
        return nil
    }

    private var code: String? {
        if let latest { return latest.sessionName.uppercased() }
        return plan?.name.uppercased()
    }

    private var word: String? {
        switch cell.mark {
        case .rest: return "REST"
        case .skipped: return "SKIP"
        case .closed: return "CLOSED"
        case .none, .planned: return nil
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: cell.day))")
                .font(Theme.TypeScale.meta.weight(.semibold))
                .foregroundStyle(cell.isCurrentMonth ? .white : .white.opacity(0.26))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let code {
                Text(code)
                    .font(Theme.TypeScale.micro)
                    .foregroundStyle(latest == nil ? Theme.roundAccent : Theme.setAccent)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
            }
            Spacer(minLength: 2)
            bar
            if let word {
                Text(word)
                    .font(Theme.TypeScale.micro)
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .top)
        .background(background)
        .overlay(alignment: .topTrailing) { countBadge }
        .overlay { todayRing }
        .opacity(cell.isDimmed ? 0.26 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        // The month is a compact map: keep its 44 pt cells legible instead of
        // letting the day, code and word scale past the cell. The day sheet
        // carries the accessibility text sizes.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    @ViewBuilder
    private var bar: some View {
        if let latest {
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule()
                    .fill(Theme.setAccent)
                    .frame(width: fillWidth(latest))
            }
            .frame(width: 22, height: 3)
        } else if plan != nil {
            Capsule()
                .stroke(Theme.roundAccent.opacity(0.55), lineWidth: 1)
                .frame(width: 22, height: 3)
        } else {
            Color.clear.frame(width: 22, height: 3)
        }
    }

    private func fillWidth(_ record: WorkoutRecord) -> CGFloat {
        guard record.totalSets > 0 else { return 0 }
        let fraction = min(max(Double(record.doneSets) / Double(record.totalSets), 0), 1)
        return 22 * CGFloat(fraction)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(cell.isCurrentMonth ? .white.opacity(0.04) : .clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(cell.isCurrentMonth ? .white.opacity(0.055) : .clear, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var todayRing: some View {
        if cell.isToday {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.55), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var countBadge: some View {
        if cell.records.count > 1 {
            Text("\(cell.records.count)")
                .font(Theme.TypeScale.micro)
                .foregroundStyle(Theme.setAccent)
                .padding(3)
        }
    }

    static func accessibilityText(_ cell: CalendarDayCell, calendar: Calendar) -> String {
        let date = cell.day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        if let latest = cell.records.max(by: { $0.startedAt < $1.startedAt }) {
            let sets = "\(latest.doneSets) of \(latest.totalSets) sets"
            return "\(date), \(latest.sessionName) record, \(sets)"
        }
        switch cell.mark {
        case .planned(let session): return "\(date), \(session.name) planned"
        case .rest: return "\(date), rest day"
        case .skipped: return "\(date), session skipped"
        case .closed: return "\(date), closed"
        case .none: return "\(date), no session"
        }
    }
}
