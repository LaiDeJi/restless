import SwiftData
import SwiftUI

struct SessionsScreen: View {
    @Environment(SessionEngine.self) private var engine
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \PresetRecord.createdAt) private var records: [PresetRecord]
    @Query(sort: \MovementRecord.createdAt) private var movements: [MovementRecord]

    private var isLocked: Bool { engine.snapshot.isLocked }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if isLocked {
                    EditingLockBanner()
                }

                ForEach(records) { record in
                    Button {
                        open(record)
                    } label: {
                        card(record)
                    }
                    .buttonStyle(.plain)
                }

                librarySection

                Text(
                    "Each round runs every movement in order for its sets-per-round sets. "
                        + "A set rest follows each set; a round rest follows each round."
                )
                    .font(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.tertiaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("WORKOUTS")
                    .font(Theme.TypeScale.section)
                    .tracking(1.2)
                    .foregroundStyle(Theme.secondaryText)

                Text("SESSIONS")
                    .font(Theme.TypeScale.screenTitle)
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                addSession()
            } label: {
                Image(systemName: "plus")
                    .font(Theme.TypeScale.value)
                    .foregroundStyle(isLocked ? .white.opacity(0.18) : .white.opacity(0.75))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .chromeGlass(
                        in: Circle(),
                        fallbackFill: .white.opacity(isLocked ? 0.03 : 0.07)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isLocked)
            .accessibilityLabel("Add session")
        }
    }

    private func card(_ record: PresetRecord) -> some View {
        let active = record.id == ActivePresetStore.id
        let total = record.preset

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        cardText(record, total: total)
                        Spacer(minLength: 8)
                        chevron
                    }

                    if active {
                        activeBadge
                    }
                }
            } else {
                HStack(spacing: 12) {
                    cardText(record, total: total)
                    Spacer(minLength: 8)
                    if active {
                        activeBadge
                    }
                    chevron
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(active ? 0.075 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(active ? Theme.setAccent.opacity(0.28) : .white.opacity(0.055), lineWidth: 1)
        )
    }

    private func cardText(_ record: PresetRecord, total: WorkoutPreset) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(record.name)
                .font(Theme.TypeScale.rowTitle)
                .tracking(0.2)
                .foregroundStyle(.white)
                .lineLimit(1)

            Text("\(plural(total.blocks.count, "BLOCK", "BLOCKS")) · \(plural(total.totalSets, "SET", "SETS")) · \(durationString(total.totalRest)) REST")
                .font(Theme.TypeScale.meta.weight(.medium))
                .tracking(0.2)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("LIBRARY")
                    .font(Theme.TypeScale.section.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(plural(movements.count, "MOVEMENT", "MOVEMENTS"))
                    .font(Theme.TypeScale.meta.weight(.semibold))
                    .tracking(0.4)
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(.top, 8)

            NavigationLink {
                MovementsScreen()
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("MOVEMENTS")
                            .font(Theme.TypeScale.rowTitle)
                            .tracking(0.2)
                            .foregroundStyle(.white)
                        Text("Recorded on the watch · reusable in any block")
                            .font(Theme.TypeScale.meta.weight(.medium))
                            .tracking(0.2)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(Theme.TypeScale.body.weight(.semibold))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.055), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var activeBadge: some View {
        Text("ACTIVE")
            .font(Theme.TypeScale.micro.weight(.bold))
            .tracking(0.6)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.setAccent))
            .fixedSize()
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(Theme.TypeScale.body.weight(.semibold))
            .foregroundStyle(Theme.tertiaryText)
    }

    private func open(_ record: PresetRecord) {
        router.sessionsPath.append(.session(record.id))
    }

    private func addSession() {
        guard !isLocked else { return }
        let preset = NewSessionDraft.make(from: activeRecord?.preset)
        router.sessionsPath.append(.newSession(preset))
    }

    private var activeRecord: PresetRecord? {
        records.first { $0.id == ActivePresetStore.id } ?? records.first
    }
}

struct EditingLockBanner: View {
    var body: some View {
        Text("EDITING LOCKED DURING A SET OR REST · SWITCH TO TIMER TO SET DONE OR PAUSE")
            .font(Theme.TypeScale.meta.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(Theme.roundAccent)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.roundAccent.opacity(0.09))
            )
    }
}
