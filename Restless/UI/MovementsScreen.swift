import SwiftData
import SwiftUI

struct MovementsScreen: View {
    @Environment(SessionEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MovementRecord.createdAt) private var records: [MovementRecord]

    private var isLocked: Bool { engine.snapshot.isLocked }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    kicker("LIBRARY")
                    Text("MOVEMENTS")
                        .font(Theme.TypeScale.screenTitle)
                        .foregroundStyle(.white)
                    Text(
                        "\(plural(records.count, "MOVEMENT", "MOVEMENTS")) · ADDED FROM A BLOCK"
                    )
                    .font(Theme.TypeScale.body)
                    .foregroundStyle(Theme.secondaryText)

                    if isLocked {
                        EditingLockBanner()
                    }

                    if records.isEmpty {
                        Text("No movements yet. Add one by typing a name in a block's add-movement picker.")
                            .font(Theme.TypeScale.body)
                            .foregroundStyle(Theme.tertiaryText)
                            .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(records) { movement in
                                NavigationLink {
                                    MovementEditorScreen(movementID: movement.id)
                                } label: {
                                    movementRow(movement)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            PlanPillButton(title: "‹ SESSIONS") {
                dismiss()
            }
        }
        .frame(minHeight: 44)
    }

    private func kicker(_ text: String) -> some View {
        Text(text)
            .font(Theme.TypeScale.section.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(Theme.secondaryText)
    }

    private func movementRow(_ movement: MovementRecord) -> some View {
        HStack(spacing: 12) {
            Text(movement.name)
                .font(Theme.TypeScale.rowTitle)
                .tracking(0.2)
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(Theme.TypeScale.body.weight(.semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.045))
        )
    }
}
