import SwiftData
import SwiftUI

struct BlockEditorScreen: View {
    let draft: SessionDraftStore
    let target: BlockEditingTarget

    @Environment(SessionEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \MovementRecord.createdAt) private var movements: [MovementRecord]

    @State private var nameDraft = ""
    @State private var deleteArmed = false
    @State private var armedMovementID: UUID?
    @State private var draggingID: UUID?
    @State private var dropTargetID: UUID?
    @State private var dragOrder: [UUID]?
    @State private var nameFieldFrame: CGRect = .zero
    @State private var showPicker = false
    @FocusState private var nameFocused: Bool

    private var isLocked: Bool { engine.snapshot.isLocked }
    private var isStaged: Bool { target == .staged }
    private var block: WorkoutBlock? { draft.block(target) }
    private var library: [UUID: Movement] {
        Dictionary(movements.map { ($0.id, $0.movement) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let block {
                content(block)
            } else {
                ProgressView().tint(.white)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .pageTapKeyboardDismiss(
            isFocused: nameFocused,
            fieldFrame: nameFieldFrame,
            coordinateSpace: "blockEditor"
        ) {
            nameFocused = false
        }
        .onAppear {
            nameDraft = block?.name ?? ""
        }
        .onChange(of: block?.name) { _, newName in
            guard !nameFocused, let newName, newName != nameDraft else { return }
            nameDraft = newName
        }
        .onChange(of: nameFocused) { _, focused in
            if !focused { commitName() }
        }
        .onDisappear {
            clearDrag()
            commitName()
            draft.flush()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            clearDrag()
            draft.flush()
        }
        .onChange(of: isLocked) { _, locked in
            if locked { clearDrag() }
        }
        .sheet(isPresented: $showPicker) {
            MovementPickerSheet(draft: draft, target: target)
        }
    }

    // MARK: Content

    private func content(_ block: WorkoutBlock) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                kicker("BLOCK")
                nameField
                summary(block)

                if isLocked {
                    EditingLockBanner()
                }

                planCounts(block)

                HStack(alignment: .firstTextBaseline) {
                    kicker("MOVEMENTS")
                    Spacer()
                    Text(plural(block.movements.count, "MOVEMENT", "MOVEMENTS"))
                        .font(Theme.TypeScale.meta)
                        .foregroundStyle(Theme.tertiaryText)
                }

                let rows = displayedMovements(block)
                VStack(spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, movement in
                        movementRow(movement, index: index, count: rows.count, block: block)
                    }
                }

                BlockLibrarySection(
                    records: movements,
                    draft: draft,
                    target: target,
                    isLocked: isLocked
                )

                orderPreview(block)
                addMovementButton(block)
                deleteButton(block)
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(draggingID != nil)
        .planEdgeDropZones(
            rowIDs: displayedMovements(block).map(\.id),
            draggingID: $draggingID,
            dropTargetID: $dropTargetID,
            onReorder: { source, target in reorder(source, onto: target) },
            onDropEnded: { commitDrag() }
        )
        .scrollDismissesKeyboard(.interactively)
    }

    /// The four numeric fields share one rounded card.
    private func planCounts(_ block: WorkoutBlock) -> some View {
        VStack(spacing: 1) {
            PlanCountRow(
                label: "ROUNDS",
                value: Binding(
                    get: { block.rounds },
                    set: { newValue in
                        edit { $0.rounds = max(newValue, Self.minimumRounds($0)) }
                    }
                ),
                minimum: Self.minimumRounds(block),
                locked: isLocked
            )

            PlanCountRow(
                label: "SETS PER ROUND",
                value: Binding(
                    get: { block.setsPerRound },
                    set: { newValue in edit { $0.setsPerRound = max(newValue, 1) } }
                ),
                locked: isLocked
            )

            PlanStepperRow(
                label: "SET REST",
                value: Binding(
                    get: { block.setRest },
                    set: { newValue in edit { $0.setRest = WorkoutPreset.clampedSetRest(newValue) } }
                ),
                range: 0...600,
                step: 15,
                format: clockString,
                locked: isLocked
            )

            PlanStepperRow(
                label: "ROUND REST",
                value: Binding(
                    get: { block.roundRest },
                    set: { newValue in edit { $0.roundRest = WorkoutPreset.clampedRest(newValue) } }
                ),
                range: 15...600,
                step: 15,
                format: clockString,
                locked: isLocked
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var header: some View {
        HStack {
            PlanPillButton(title: "‹ SESSION") {
                close()
            }

            Spacer()

            PlanPillButton(
                title: "DONE",
                prominent: true,
                enabled: !isStaged || !(block?.movements.isEmpty ?? true)
            ) {
                done()
            }
        }
    }

    private func kicker(_ text: String) -> some View {
        Text(text)
            .font(Theme.TypeScale.section.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(Theme.secondaryText)
    }

    private var nameField: some View {
        TextField("Block name", text: $nameDraft)
            .font(Theme.TypeScale.pageTitle)
            .foregroundStyle(.white)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .focused($nameFocused)
            .disabled(isLocked)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named("blockEditor"))
            } action: { frame in
                nameFieldFrame = frame
            }
            .onSubmit {
                nameDraft = NameRules.block(nameDraft)
                nameFocused = false
            }
            .onChange(of: nameDraft) { _, value in
                let capped = NameRules.live(value)
                if capped != value {
                    nameDraft = capped
                    return
                }
                edit { $0.name = capped }
            }
    }

    private func summary(_ block: WorkoutBlock) -> some View {
        Text(blockSummary(block))
            .font(Theme.TypeScale.body)
            .tracking(0.2)
            .foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func movementRow(
        _ movement: BlockMovement,
        index: Int,
        count: Int,
        block: WorkoutBlock
    ) -> some View {
        let armed = armedMovementID == movement.id
        return PlanListRow(
            itemID: movement.id,
            canDelete: count > 1,
            isArmed: armed,
            isLocked: isLocked,
            deleteLabel: "Delete movement",
            draggingID: $draggingID,
            dropTargetID: $dropTargetID,
            onMoveUp: { move(movement.id, by: -1, block: block) },
            onMoveDown: { move(movement.id, by: 1, block: block) },
            onDelete: { deleteMovement(movement.id, block: block) },
            onReorder: { source, destination in
                reorder(source, onto: destination)
            },
            onDropEnded: { commitDrag() },
            onDragBegan: { beginDrag() },
            onDragEnded: { completed in
                endDrag(completed: completed)
            },
            content: {
                movementContent(movement, index: index, armed: armed)
            },
            destination: {
                BlockMovementEditorScreen(draft: draft, target: target, movementID: movement.id)
            }
        )
    }

    private func movementContent(_ movement: BlockMovement, index: Int, armed: Bool) -> some View {
        let libraryMovement = library[movement.movementId]
        return HStack(spacing: 12) {
            Text(String(format: "%02d", index + 1))
                .font(Theme.TypeScale.meta.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.tertiaryText)
                .frame(minWidth: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(libraryMovement?.name ?? "Missing movement")
                    .font(Theme.TypeScale.rowTitle)
                    .tracking(0.2)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(armed ? "TAP AGAIN TO DELETE" : conditionLabel(movement))
                    .font(Theme.TypeScale.meta)
                    .tracking(0.2)
                    .foregroundStyle(armed ? Theme.destructive : Theme.secondaryText)
            }
        }
    }

    private func deleteMovement(_ movementID: UUID, block: WorkoutBlock) {
        guard !isLocked else { return }
        guard armedMovementID == movementID else {
            armedMovementID = movementID
            return
        }
        armedMovementID = nil
        guard draft.removeMovement(movementID, in: target) else { return }
        draft.flush()
    }

    private func conditionLabel(_ movement: BlockMovement) -> String {
        switch movement.endCondition {
        case .manual: "MANUAL"
        case .reps: "\(movement.target ?? 1) REPS"
        case .time: "TIME \(clockString(movement.target ?? 60))"
        }
    }

    private func orderPreview(_ block: WorkoutBlock) -> some View {
        let names = block.movements.map { (library[$0.movementId]?.name ?? "Movement").uppercased() }
        let rounds = plural(max(block.rounds, 1), "ROUND", "ROUNDS")
        let sets = max(block.setsPerRound, 1)
        let text: String
        if names.isEmpty {
            text = "\(rounds) · NO MOVEMENTS"
        } else {
            text = "\(rounds) · " + names.map { "\($0) × \(sets)" }.joined(separator: " → ")
        }
        return Text("ORDER · " + text)
            .font(Theme.TypeScale.meta)
            .tracking(0.3)
            .foregroundStyle(Theme.tertiaryText)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(0.03))
            )
    }

    private func addMovementButton(_ block: WorkoutBlock) -> some View {
        Button {
            guard !isLocked else { return }
            commitName()
            showPicker = true
        } label: {
            Text("+ ADD MOVEMENT")
                .font(Theme.TypeScale.compactAction.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(isLocked ? .white.opacity(0.2) : .white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(isLocked ? 0.04 : 0.09), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }

    @ViewBuilder
    private func deleteButton(_ block: WorkoutBlock) -> some View {
        if !isStaged, draft.session.blocks.count > 1 {
            Button {
                guard !isLocked else { return }
                guard deleteArmed else {
                    deleteArmed = true
                    return
                }
                draft.edit { session in
                    session.blocks.removeAll { $0.id == block.id }
                }
                dismiss()
            } label: {
                Text(deleteArmed ? "TAP AGAIN TO DELETE" : "DELETE BLOCK")
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

    // MARK: Actions

    /// A block with two or more movements keeps at least two rounds, so a
    /// superset is not authored as a single pass by accident.
    private static func minimumRounds(_ block: WorkoutBlock) -> Int {
        block.movements.count > 1 ? 2 : 1
    }

    private func edit(_ mutate: @escaping (inout WorkoutBlock) -> Void) {
        draft.editBlock(target, mutate)
    }

    private func move(_ movementID: UUID, by delta: Int, block: WorkoutBlock) {
        guard !isLocked,
              let index = block.movements.firstIndex(where: { $0.id == movementID })
        else { return }
        let destination = index + delta
        guard block.movements.indices.contains(destination) else { return }
        draft.moveMovement(movementID, in: target, onto: block.movements[destination].id)
        draft.flush()
    }

    private func commitName() {
        guard let block else { return }
        let name = NameRules.block(nameDraft)
        nameDraft = name
        guard block.name != name else { return }
        edit { $0.name = name }
    }

    private func clearDrag() {
        draggingID = nil
        dropTargetID = nil
        dragOrder = nil
        draft.endDrag()
    }

    /// The provisional order while a drag is down; the block's order otherwise.
    private func displayedMovements(_ block: WorkoutBlock) -> [BlockMovement] {
        guard let dragOrder else { return block.movements }
        let byID = Dictionary(uniqueKeysWithValues: block.movements.map { ($0.id, $0) })
        return dragOrder.compactMap { byID[$0] }
    }

    private func beginDrag() {
        guard !isLocked, dragOrder == nil, let block = draft.block(target) else { return }
        dragOrder = block.movements.map(\.id)
        draft.beginDrag()
    }

    /// A crossing only permutes the provisional array. A saved block reaches
    /// the draft once on drop; a staged block is written directly, no flush.
    private func reorder(_ source: UUID, onto targetID: UUID) {
        guard !isLocked else { return }
        if dragOrder == nil { beginDrag() }
        guard let order = dragOrder,
              let from = order.firstIndex(of: source),
              let to = order.firstIndex(of: targetID),
              from != to
        else { return }
        var moved = order
        let id = moved.remove(at: from)
        moved.insert(id, at: to)
        withAnimation(.smooth(duration: 0.26)) { dragOrder = moved }
    }

    private func commitDrag() {
        guard let order = dragOrder else { return }
        dragOrder = nil
        if let block = draft.block(target), order != block.movements.map(\.id) {
            draft.reorderMovements(in: target, to: order)
        }
        draft.endDrag()
    }

    private func endDrag(completed: Bool) {
        if completed {
            commitDrag()
        } else {
            withAnimation(.smooth(duration: 0.26)) { dragOrder = nil }
            draft.endDrag()
        }
    }

    private func close() {
        commitName()
        draft.flush()
        dismiss()
    }

    /// DONE is the commit for a staged block; back is the discard.
    private func done() {
        commitName()
        if isStaged {
            guard draft.commitStagedBlock() else { return }
        }
        draft.flush()
        dismiss()
    }
}
