import SwiftData
import SwiftUI

struct MovementPickerSheet: View {
    let draft: SessionDraftStore
    let target: BlockEditingTarget

    @Environment(SessionEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \MovementRecord.createdAt) private var records: [MovementRecord]

    @State private var condition: EndCondition = .manual
    @State private var targetValue = 10
    @State private var newName = ""
    @State private var pending = PendingMovementList()
    @State private var nameFieldFrame: CGRect = .zero
    @FocusState private var newNameFocused: Bool

    private var isLocked: Bool { engine.snapshot.isLocked }
    private var canQueueNewName: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !pending.contains(name: WorkoutPreset.clampedName(newName, fallback: ""))
    }
    private var canCommit: Bool { !isLocked }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    kicker("ADD MOVEMENT")
                    Text("SET END")
                        .font(Theme.TypeScale.screenTitle)
                        .foregroundStyle(.white)
                    Text("Choose how the set ends, then queue a recorded movement or name a new one.")
                        .font(Theme.TypeScale.body)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if isLocked {
                        EditingLockBanner()
                    }

                    EndConditionPicker(
                        selection: Binding(
                            get: { condition },
                            set: { newValue in
                                condition = newValue
                                if newValue != .manual {
                                    targetValue = newValue.clampedTarget(targetValue) ?? targetValue
                                }
                            }
                        ),
                        locked: isLocked
                    )

                    if condition == .manual {
                        Text("NO TARGET · TAP SET DONE WHEN THE SET ENDS.")
                            .font(Theme.TypeScale.meta)
                            .foregroundStyle(Theme.secondaryText)
                    } else {
                        PlanStepperRow(
                            label: "TARGET",
                            value: $targetValue,
                            range: condition == .time ? 15...600 : 1...Int.max,
                            step: condition == .time ? 15 : 1,
                            format: { condition == .time ? clockString($0) : "\($0)" },
                            locked: isLocked
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    kicker("NEW MOVEMENT")

                    TextField("Movement name", text: $newName)
                        .font(Theme.TypeScale.rowTitle)
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($newNameFocused)
                        .disabled(isLocked)
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .named("movementPicker"))
                        } action: { frame in
                            nameFieldFrame = frame
                        }
                        .onSubmit(queueNewName)
                        .onChange(of: newName) { _, value in
                            let capped = NameRules.live(value)
                            if capped != value {
                                newName = capped
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.045))
                        )

                    if condition.requiresWatchProfile {
                        Text("NO PROFILE · THE WATCH CANNOT COUNT IT UNTIL IT IS RECORDED.")
                            .font(Theme.TypeScale.meta.weight(.semibold))
                            .tracking(0.4)
                            .foregroundStyle(Theme.roundAccent)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: queueNewName) {
                        Text("ADD MOVEMENT")
                            .font(Theme.TypeScale.compactAction.weight(.bold))
                            .tracking(1.0)
                            .foregroundStyle(
                                canQueueNewName && !isLocked ? Theme.ink : .white.opacity(0.3)
                            )
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .background(
                                Capsule().fill(
                                    canQueueNewName && !isLocked
                                        ? Theme.setAccent
                                        : Color.white.opacity(0.07)
                                )
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canQueueNewName || isLocked)

                    pendingSection

                    HStack(alignment: .firstTextBaseline) {
                        kicker("MOVEMENT")
                        Spacer()
                        Text(plural(records.count, "MOVEMENT", "MOVEMENTS"))
                            .font(Theme.TypeScale.meta)
                            .foregroundStyle(Theme.tertiaryText)
                    }

                    if records.isEmpty {
                        Text("No movements yet. Record one first.")
                            .font(Theme.TypeScale.body)
                            .foregroundStyle(Theme.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(records) { record in
                                Button {
                                    toggle(record)
                                } label: {
                                    row(record)
                                }
                                .buttonStyle(.plain)
                                .disabled(isLocked)
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .pageTapKeyboardDismiss(
            isFocused: newNameFocused,
            fieldFrame: nameFieldFrame,
            coordinateSpace: "movementPicker"
        ) {
            newNameFocused = false
        }
    }

    private var header: some View {
        HStack {
            PlanPillButton(title: "CANCEL") {
                dismiss()
            }

            Spacer()

            PlanPillButton(title: "DONE", prominent: true, enabled: canCommit) {
                commit()
            }
        }
        .padding(.top, 6)
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                kicker("TO ADD")
                Spacer()
                Text(plural(pending.count, "MOVEMENT", "MOVEMENTS"))
                    .font(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.tertiaryText)
            }

            if pending.isEmpty {
                Text("Nothing queued yet. Add a movement or tap one below.")
                    .font(Theme.TypeScale.body)
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                ForEach(pending.items) { item in
                    pendingRow(item)
                }
            }
        }
    }

    private func pendingRow(_ item: PendingMovement) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(Theme.TypeScale.rowTitle)
                    .tracking(0.2)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(conditionText(item.condition, item.target))
                    .font(Theme.TypeScale.meta)
                    .tracking(0.2)
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 8)

            Button {
                guard !isLocked else { return }
                pending.remove(item.id)
            } label: {
                Image(systemName: "xmark")
                    .font(Theme.TypeScale.body.weight(.semibold))
                    .foregroundStyle(Theme.destructive.opacity(isLocked ? 0.2 : 0.75))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLocked)
            .accessibilityLabel("Remove \(item.name)")
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.setAccent.opacity(0.4), lineWidth: 1)
        )
    }

    private func kicker(_ text: String) -> some View {
        Text(text)
            .font(Theme.TypeScale.section.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(Theme.secondaryText)
    }

    private func row(_ record: MovementRecord) -> some View {
        let queued = pending.contains(movementID: record.id)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.name)
                    .font(Theme.TypeScale.rowTitle)
                    .tracking(0.2)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(record.movement.profile?.usesForearmSignal == true ? "PROFILE" : "NO PROFILE")
                    .font(Theme.TypeScale.meta)
                    .tracking(0.2)
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 8)

            Image(systemName: queued ? "checkmark" : "plus")
                .font(Theme.TypeScale.body.weight(.semibold))
                .foregroundStyle(queued ? Theme.setAccent : Theme.tertiaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(queued ? Theme.setAccent.opacity(0.08) : .white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(queued ? Theme.setAccent.opacity(0.5) : .clear, lineWidth: 1)
        )
    }

    private func conditionText(_ condition: EndCondition, _ target: Int?) -> String {
        switch condition {
        case .manual: "MANUAL"
        case .reps: "\(target ?? 1) REPS"
        case .time: "TIME \(clockString(target ?? 60))"
        }
    }

    private func toggle(_ record: MovementRecord) {
        guard !isLocked else { return }
        pending.toggle(
            record.movement,
            condition: condition,
            target: condition == .manual ? nil : targetValue
        )
    }

    private func queueNewName() {
        guard !isLocked, canQueueNewName else { return }
        guard pending.queue(
            name: newName,
            condition: condition,
            target: condition == .manual ? nil : targetValue
        ) else { return }
        newName = ""
    }

    private func commit() {
        guard canCommit else { return }
        let additions = resolvedAdditions()
        if !additions.isEmpty {
            guard draft.appendMovements(additions, to: target) else { return }
            draft.flush()
        }
        dismiss()
    }

    /// Resolves typed names through the library (reusing an existing name) and
    /// returns every queued movement in display order.
    private func resolvedAdditions() -> [MovementAddition] {
        pending.items.compactMap { item in
            let movement: Movement?
            if let movementID = item.movementID {
                movement = records.first { $0.id == movementID }?.movement
            } else {
                movement = MovementRepository.addOrReuse(name: item.name, in: context)
            }
            guard let movement else { return nil }
            return MovementAddition(
                movement: movement,
                condition: item.condition,
                target: item.target
            )
        }
    }
}
