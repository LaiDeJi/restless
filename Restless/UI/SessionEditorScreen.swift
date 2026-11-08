import SwiftData
import SwiftUI

enum SessionEditorMode: Hashable {
    /// A saved record, edited in place.
    case existing(UUID)
    /// An unsaved draft; DONE or USE creates the record.
    case draft(WorkoutPreset)
}

struct SessionEditorScreen: View {
    let mode: SessionEditorMode

    @Environment(\.modelContext) private var context
    @Environment(SessionEngine.self) private var engine
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \PresetRecord.createdAt) private var records: [PresetRecord]

    @State private var draft: SessionDraftStore?
    @State private var committed = false
    @State private var nameDraft = ""
    @State private var deleteArmed = false
    @State private var armedBlockID: UUID?
    @State private var draggingID: UUID?
    @State private var dropTargetID: UUID?
    @State private var nameFieldFrame: CGRect = .zero
    @State private var showingNewBlock = false
    @FocusState private var nameFocused: Bool

    private var isLocked: Bool { engine.snapshot.isLocked }
    private var isDraft: Bool { if case .draft = mode { true } else { false } }
    private var existingID: UUID? { if case .existing(let id) = mode { id } else { nil } }
    private var isActive: Bool {
        guard let existingID else { return false }
        return ActivePresetStore.id == existingID
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let draft {
                content(draft)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .pageTapKeyboardDismiss(
            isFocused: nameFocused,
            fieldFrame: nameFieldFrame,
            coordinateSpace: "sessionEditor"
        ) {
            nameFocused = false
        }
        .onAppear(perform: load)
        .onChange(of: records.count) { _, _ in load() }
        .onDisappear {
            clearDrag()
            flushOnExit()
        }
        .onChange(of: nameFocused) { _, focused in
            if !focused { commitName() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            clearDrag()
            flushOnExit()
        }
        .onChange(of: isLocked) { _, locked in
            if locked { clearDrag() }
        }
        .navigationDestination(isPresented: $showingNewBlock) {
            if let draft {
                BlockEditorScreen(draft: draft, target: .staged)
            }
        }
        .onChange(of: showingNewBlock) { _, showing in
            guard !showing else { return }
            draft?.discardStagedBlock()
        }
    }

    // MARK: Content

    private func content(_ draft: SessionDraftStore) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                kicker("SESSION")
                nameField
                summary(draft.session)

                if isActive && engine.snapshot.doneSets > 0 && !isLocked {
                    Text("EDITING THIS SESSION RESTARTS IT.")
                        .font(Theme.TypeScale.meta.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.roundAccent)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isLocked {
                    EditingLockBanner()
                }

                kicker("BLOCKS")

                VStack(spacing: 8) {
                    ForEach(Array(draft.session.blocks.enumerated()), id: \.element.id) { index, block in
                        blockRow(block, index: index, count: draft.session.blocks.count, draft: draft)
                    }
                }

                addBlockButton(draft)
                footer(draft)
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        HStack {
            PlanPillButton(title: "‹ SESSIONS") {
                close()
            }

            Spacer()

            PlanPillButton(title: "DONE", prominent: true) {
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
        TextField("Session name", text: $nameDraft)
            .font(Theme.TypeScale.pageTitle)
            .foregroundStyle(.white)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .focused($nameFocused)
            .disabled(isLocked)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named("sessionEditor"))
            } action: { frame in
                nameFieldFrame = frame
            }
            .onSubmit(commitName)
            .onChange(of: nameDraft) { _, value in
                let capped = NameRules.live(value)
                if capped != value {
                    nameDraft = capped
                    return
                }
                guard !capped.isEmpty else { return }
                draft?.edit { $0.name = capped }
            }
    }

    private func summary(_ session: WorkoutPreset) -> some View {
        Text("\(plural(session.blocks.count, "BLOCK", "BLOCKS")) · \(plural(session.totalSets, "SET", "SETS")) · \(durationString(session.totalRest)) TOTAL REST")
            .font(Theme.TypeScale.body)
            .tracking(0.2)
            .foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func blockRow(
        _ block: WorkoutBlock,
        index: Int,
        count: Int,
        draft: SessionDraftStore
    ) -> some View {
        let armed = armedBlockID == block.id
        return PlanListRow(
            itemID: block.id,
            canDelete: count > 1,
            isArmed: armed,
            isLocked: isLocked,
            deleteLabel: "Delete block",
            draggingID: $draggingID,
            dropTargetID: $dropTargetID,
            onMoveUp: { move(block.id, by: -1, draft: draft) },
            onMoveDown: { move(block.id, by: 1, draft: draft) },
            onDelete: { deleteBlock(block.id, draft: draft) },
            onReorder: { source, target in
                guard !isLocked else { return }
                draft.moveBlock(source, onto: target)
            },
            onDropEnded: { draft.flush() },
            content: {
                blockContent(block, index: index, armed: armed)
            },
            destination: {
                BlockEditorScreen(draft: draft, target: .saved(block.id))
            }
        )
    }

    private func blockContent(_ block: WorkoutBlock, index: Int, armed: Bool) -> some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index + 1))
                .font(Theme.TypeScale.meta.weight(.semibold))
                .tracking(0.4)
                .monospacedDigit()
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(block.name)
                    .font(Theme.TypeScale.rowTitle)
                    .tracking(0.2)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(armed ? "TAP AGAIN TO DELETE" : blockMeta(block))
                    .font(Theme.TypeScale.meta)
                    .tracking(0.2)
                    .foregroundStyle(armed ? Theme.destructive : Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func addBlockButton(_ draft: SessionDraftStore) -> some View {
        Button {
            addBlock(draft)
        } label: {
            Text("+ ADD BLOCK")
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
    private func footer(_ draft: SessionDraftStore) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if isDraft {
                Button {
                    use(draft)
                } label: {
                    footerButtonLabel("USE THIS SESSION", prominent: true)
                }
                .buttonStyle(.plain)
                .disabled(isLocked)
            } else if isActive {
                if engine.snapshot.doneSets > 0 {
                    Button {
                        restart(draft)
                    } label: {
                        footerButtonLabel("RESTART SESSION", prominent: false)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked)
                } else {
                    Text("ACTIVE SESSION")
                        .font(Theme.TypeScale.action)
                        .tracking(0.6)
                        .foregroundStyle(Theme.setAccent.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                }
            } else {
                Button {
                    use(draft)
                } label: {
                    footerButtonLabel("USE THIS SESSION", prominent: true)
                }
                .buttonStyle(.plain)
                .disabled(isLocked)
            }

            if !isDraft && records.count > 1 {
                Button {
                    deleteSession()
                } label: {
                    Text(deleteArmed ? "TAP AGAIN TO DELETE" : "DELETE SESSION")
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
            }
        }
        .padding(.top, 8)
    }

    private func footerButtonLabel(_ title: String, prominent: Bool) -> some View {
        Text(title)
            .font(Theme.TypeScale.action)
            .tracking(0.6)
            .foregroundStyle(prominent ? Theme.ink : (isLocked ? .white.opacity(0.2) : .white.opacity(0.7)))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(
                Capsule().fill(
                    prominent
                        ? (isLocked ? Color.white.opacity(0.1) : Theme.setAccent)
                        : Color.white.opacity(0.07)
                )
            )
            .contentShape(Capsule())
    }

    // MARK: Actions

    private func load() {
        guard draft == nil else { return }

        switch mode {
        case .draft(let preset):
            draft = SessionDraftStore(session: preset)
            nameDraft = preset.name
        case .existing(let id):
            guard let record = records.first(where: { $0.id == id }) else {
                if !records.isEmpty { dismiss() }
                return
            }
            let store = SessionDraftStore(session: record.preset)
            store.commit = { [context, engine] updated in
                let normalized = NameRules.normalize(updated)
                guard let record = PresetRepository.fetchAll(context).first(where: { $0.id == normalized.id }) else {
                    return
                }
                record.apply(normalized)
                try? context.save()
                if ActivePresetStore.id == record.id {
                    engine.use(normalized)
                }
            }
            draft = store
            nameDraft = record.name
        }
    }

    private func move(_ blockID: UUID, by delta: Int, draft: SessionDraftStore) {
        guard !isLocked,
              let index = draft.session.blocks.firstIndex(where: { $0.id == blockID })
        else { return }
        let target = index + delta
        guard draft.session.blocks.indices.contains(target) else { return }
        draft.moveBlock(blockID, onto: draft.session.blocks[target].id)
        draft.flush()
    }

    private func deleteBlock(_ blockID: UUID, draft: SessionDraftStore) {
        guard !isLocked else { return }
        guard armedBlockID == blockID else {
            armedBlockID = blockID
            return
        }
        armedBlockID = nil
        guard draft.removeBlock(blockID) else { return }
        draft.flush()
    }

    private func addBlock(_ draft: SessionDraftStore) {
        guard !isLocked, !showingNewBlock else { return }
        draft.beginStagedBlock(after: draft.session.blocks.last)
        guard draft.stagedBlock != nil else { return }
        showingNewBlock = true
    }

    private func commitName() {
        guard let draft else { return }
        let name = NameRules.session(nameDraft)
        nameDraft = name
        guard draft.session.name != name else { return }
        draft.edit { $0.name = name }
    }

    private func flushAll() {
        commitName()
        draft?.flush()
    }

    /// Backgrounding and dismissal persist a saved record's pending edit. A
    /// draft has no commit, so leaving it never creates a record.
    private func flushOnExit() {
        guard !isDraft else { return }
        flushAll()
    }

    private func clearDrag() {
        draggingID = nil
        dropTargetID = nil
    }

    private func close() {
        if isDraft {
            dismiss()
        } else {
            flushAll()
            dismiss()
        }
    }

    private func done() {
        if isDraft {
            commitDraft()
            dismiss()
        } else {
            close()
        }
    }

    @discardableResult
    private func commitDraft() -> PresetRecord? {
        guard case .draft = mode, !committed, let draft else { return nil }
        committed = true
        commitName()
        let used = PresetRepository.fetchAll(context).map(\.name)
        return SessionDraftCommit.save(draft.session, usedNames: used, in: context)
    }

    private func use(_ draft: SessionDraftStore) {
        switch mode {
        case .existing(let id):
            flushAll()
            let session = NameRules.normalize(draft.session)
            ActivePresetStore.id = id
            engine.use(session)
            router.showTimer()
            router.sessionsPath.removeAll()
        case .draft:
            guard !isLocked, let record = commitDraft() else { return }
            ActivePresetStore.id = record.id
            engine.use(record.preset)
            router.showTimer()
            router.sessionsPath.removeAll()
        }
    }

    private func restart(_ draft: SessionDraftStore) {
        guard case .existing = mode else { return }
        flushAll()
        engine.use(NameRules.normalize(draft.session), startImmediately: true)
        router.showTimer()
        router.sessionsPath.removeAll()
    }

    private func deleteSession() {
        guard !isDraft, !isLocked, records.count > 1, let existingID else { return }
        guard deleteArmed else {
            deleteArmed = true
            return
        }
        flushAll()
        guard let record = records.first(where: { $0.id == existingID }) else { return }
        context.delete(record)
        try? context.save()

        if ActivePresetStore.id == existingID,
           let next = records.first(where: { $0.id != existingID }) {
            ActivePresetStore.id = next.id
            engine.use(next.preset)
        }
        router.sessionsPath.removeAll()
    }
}
