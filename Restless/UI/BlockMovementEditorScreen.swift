import SwiftData
import SwiftUI

struct BlockMovementEditorScreen: View {
    let draft: SessionDraftStore
    let target: BlockEditingTarget
    let movementID: UUID

    @Environment(SessionEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MovementRecord.createdAt) private var movements: [MovementRecord]

    @State private var deleteArmed = false

    private var isLocked: Bool { engine.snapshot.isLocked }
    private var block: WorkoutBlock? { draft.block(target) }
    private var movement: BlockMovement? { block?.movements.first { $0.id == movementID } }
    private var libraryMovement: Movement? {
        guard let movement else { return nil }
        return movements.first { $0.id == movement.movementId }?.movement
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let block, let movement {
                content(block: block, movement: movement)
            } else {
                ProgressView().tint(.white)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onDisappear { draft.flush() }
    }

    private func content(block: WorkoutBlock, movement: BlockMovement) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                kicker("MOVEMENT")
                Text(libraryMovement?.name ?? "Missing movement")
                    .font(Theme.TypeScale.pageTitle)
                    .foregroundStyle(.white)
                Text(blockRoundSetCopy(block))
                    .font(Theme.TypeScale.body)
                    .foregroundStyle(Theme.secondaryText)

                if isLocked {
                    EditingLockBanner()
                }

                kicker("END CONDITION")

                EndConditionPicker(
                    selection: Binding(
                        get: { movement.endCondition },
                        set: { condition in
                            edit { target in
                                target.endCondition = condition
                                target.target = condition == .manual ? nil : condition.clampedTarget(target.target)
                            }
                        }
                    ),
                    locked: isLocked
                )

                if movement.endCondition == .manual {
                    Text("NO TARGET · TAP SET DONE WHEN THE SET ENDS.")
                        .font(Theme.TypeScale.meta)
                        .foregroundStyle(Theme.secondaryText)
                } else {
                    VStack(spacing: 1) {
                        PlanStepperRow(
                            label: "TARGET",
                            value: Binding(
                                get: { movement.target ?? defaultTarget },
                                set: { newValue in edit { $0.target = newValue } }
                            ),
                            range: 15...600,
                            step: 15,
                            format: { clockString($0) },
                            locked: isLocked
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                removeButton(block: block, movement: movement)
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
    }

    private var defaultTarget: Int {
        movement?.endCondition == .time ? 60 : 10
    }

    private var header: some View {
        HStack {
            PlanPillButton(title: "‹ BLOCK") {
                draft.flush()
                dismiss()
            }

            Spacer()

            PlanPillButton(title: "DONE", prominent: true) {
                draft.flush()
                dismiss()
            }
        }
    }

    private func kicker(_ text: String) -> some View {
        Text(text)
            .font(Theme.TypeScale.section.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(Theme.secondaryText)
    }

    @ViewBuilder
    private func removeButton(block: WorkoutBlock, movement: BlockMovement) -> some View {
        if block.movements.count > 1 {
            Button {
                guard !isLocked else { return }
                guard deleteArmed else {
                    deleteArmed = true
                    return
                }
                _ = draft.removeMovement(movement.id, in: target)
                draft.flush()
                dismiss()
            } label: {
                Text(deleteArmed ? "TAP AGAIN TO DELETE" : "REMOVE FROM BLOCK")
                    .font(Theme.TypeScale.meta.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(
                        Theme.destructive.opacity(isLocked ? 0.2 : (deleteArmed ? 1 : 0.62))
                    )
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(
                        Capsule().fill(deleteArmed ? Theme.destructive.opacity(0.12) : .clear)
                    )
                    .overlay(
                        Capsule().stroke(
                            deleteArmed ? Theme.destructive.opacity(0.34) : .clear,
                            lineWidth: 1
                        )
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isLocked)
            .padding(.top, 4)
        }
    }

    private func edit(_ mutate: @escaping (inout BlockMovement) -> Void) {
        draft.editBlock(target) { block in
            guard let index = block.movements.firstIndex(where: { $0.id == movementID }) else { return }
            mutate(&block.movements[index])
        }
    }
}
