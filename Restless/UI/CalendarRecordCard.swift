import SwiftUI

/// One recorded run, read-only: the session name, sets, start time and
/// duration, each snapshot block with its rests, and the phase it stopped in.
struct CalendarRecordCard: View {
    let record: WorkoutRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(record.sessionName)
                    .font(Theme.TypeScale.rowTitle)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text("\(record.doneSets) OF \(record.totalSets) SETS")
                    .font(Theme.TypeScale.micro)
                    .tracking(0.5)
                    .foregroundStyle(Theme.setAccent)
                    .fixedSize()
            }

            Text(CalendarCopy.recordWhen(record))
                .font(Theme.TypeScale.micro)
                .tracking(0.5)
                .foregroundStyle(Theme.secondaryText)

            ForEach(record.preset.blocks) { block in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(block.name) · \(blockNumbers(block))")
                        .font(Theme.TypeScale.meta)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(CalendarCopy.blockRestSummary(block))
                        .font(Theme.TypeScale.micro)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }

            Text(phaseCopy)
                .font(Theme.TypeScale.micro)
                .tracking(0.6)
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        )
    }

    private var phaseCopy: String {
        if record.isFinished { return "FINISHED" }
        switch record.phase {
        case .paused: return "PAUSED"
        case .resting: return "STOPPED DURING A REST"
        case .performing: return "STOPPED MID-SET"
        case .ready: return "STOPPED BETWEEN SETS"
        case .done: return "FINISHED"
        case .notStarted: return "NOT STARTED"
        }
    }
}
