import SwiftData
import SwiftUI

/// The block editor's one-tap library path: every recorded movement not already
/// in the block, appended with MANUAL and no target. Hidden while editing is
/// locked and absent when the block already uses the whole library.
struct BlockLibrarySection: View {
    let records: [MovementRecord]
    let draft: SessionDraftStore
    let target: BlockEditingTarget
    let isLocked: Bool

    private var unused: [MovementRecord] {
        guard let block = draft.block(target) else { return [] }
        let used = Set(block.movements.map(\.movementId))
        return records.filter { !used.contains($0.id) }
    }

    var body: some View {
        if !isLocked, !unused.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("ADD FROM LIBRARY")
                        .font(Theme.TypeScale.section.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text(plural(unused.count, "MOVEMENT", "MOVEMENTS"))
                        .font(Theme.TypeScale.meta)
                        .foregroundStyle(Theme.tertiaryText)
                }

                VStack(spacing: 8) {
                    ForEach(unused) { record in
                        Button {
                            add(record)
                        } label: {
                            row(record)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add \(record.name)")
                    }
                }
            }
        }
    }

    private func row(_ record: MovementRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.name)
                    .font(Theme.TypeScale.rowTitle)
                    .tracking(0.2)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(record.movement.profile?.usesForearmSignal == true
                     ? "PROFILE · MANUAL"
                     : "NO PROFILE · MANUAL")
                    .font(Theme.TypeScale.meta)
                    .tracking(0.2)
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 8)

            Image(systemName: "plus")
                .font(Theme.TypeScale.body.weight(.semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.045))
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// One discrete edit, flushed at once: the fast path for the usual single
    /// movement, not a debounced burst.
    private func add(_ record: MovementRecord) {
        guard !isLocked else { return }
        guard draft.appendMovements(
            [MovementAddition(movement: record.movement, condition: .manual, target: nil)],
            to: target
        ) else { return }
        draft.flush()
    }
}
