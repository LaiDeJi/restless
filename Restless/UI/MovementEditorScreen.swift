import SwiftData
import SwiftUI

struct MovementEditorScreen: View {
    let movementID: UUID

    @Environment(\.modelContext) private var context
    @Environment(SessionEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MovementRecord.createdAt) private var records: [MovementRecord]

    @State private var name = ""
    @State private var deleteArmed = false
    @State private var showRecording = false
    @State private var loaded = false
    @State private var saveTask: Task<Void, Never>?
    @State private var nameFieldFrame: CGRect = .zero
    @FocusState private var nameFocused: Bool

    private var record: MovementRecord? { records.first { $0.id == movementID } }
    private var isLocked: Bool { engine.snapshot.isLocked }
    private var usage: [String] { MovementRepository.usage(movementID, in: context) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if record != nil {
                content
            } else {
                ProgressView().tint(.white)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .pageTapKeyboardDismiss(
            isFocused: nameFocused,
            fieldFrame: nameFieldFrame,
            coordinateSpace: "movementEditor"
        ) {
            nameFocused = false
        }
        .onAppear { load() }
        .onChange(of: records.count) { _, _ in load() }
        .onChange(of: nameFocused) { _, focused in
            if !focused {
                name = NameRules.movement(name)
                saveNow()
            }
        }
        .onChange(of: showRecording) { _, shown in
            if !shown { load(); saveNow() }
        }
        .onDisappear {
            saveTask?.cancel()
            saveNow()
        }
        .sheet(isPresented: $showRecording) {
            RecordingSheet(movementID: movementID)
        }
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                kicker("MOVEMENT")
                nameField
                Text(usage.isEmpty ? "NOT IN A SESSION" : "USED IN \(usage.joined(separator: " · ").uppercased())")
                    .font(Theme.TypeScale.body)
                    .foregroundStyle(Theme.secondaryText)

                if isLocked {
                    EditingLockBanner()
                }

                kicker("PROFILE")
                Text(profileText)
                    .font(Theme.TypeScale.body)
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(3)

                reRecordButton
                deleteButton
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
            PlanPillButton(title: "‹ LIBRARY") {
                close()
            }

            Spacer()

            PlanPillButton(title: "DONE", prominent: true) {
                close()
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
        TextField("Movement name", text: $name)
            .font(Theme.TypeScale.pageTitle)
            .foregroundStyle(.white)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .focused($nameFocused)
            .disabled(isLocked)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named("movementEditor"))
            } action: { frame in
                nameFieldFrame = frame
            }
            .onSubmit {
                name = NameRules.movement(name)
                nameFocused = false
            }
            .onChange(of: name) { _, value in
                let capped = NameRules.live(value)
                if capped != value {
                    name = capped
                    return
                }
                scheduleSave()
            }
    }

    private var profileText: String {
        guard let profile = record?.movement.profile, profile.usesForearmSignal else {
            return "NO PROFILE · RE-RECORD TO ENABLE THE WATCH COUNT."
        }
        return "FOREARM ANGLE · RISE \(String(format: "%.0f", profile.rise))° · FALL \(String(format: "%.0f", profile.fall))° · MIN PERIOD \(String(format: "%.2f", profile.minPeriod)) s"
    }

    private var reRecordButton: some View {
        Button {
            guard !isLocked else { return }
            saveNow()
            showRecording = true
        } label: {
            Text("RE-RECORD ON WATCH")
                .font(Theme.TypeScale.action)
                .tracking(0.6)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(Capsule().fill(isLocked ? Color.white.opacity(0.1) : Theme.setAccent))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var deleteButton: some View {
        if usage.isEmpty {
            Button {
                guard !isLocked else { return }
                guard deleteArmed else {
                    deleteArmed = true
                    return
                }
                try? MovementRepository.delete(movementID, in: context)
                dismiss()
            } label: {
                Text(deleteArmed ? "TAP AGAIN TO DELETE" : "DELETE MOVEMENT")
                    .font(Theme.TypeScale.meta.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(deleteArmed ? Theme.roundAccent : .white.opacity(isLocked ? 0.16 : 0.35))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLocked)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("DELETE MOVEMENT")
                    .font(Theme.TypeScale.meta.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.16))
                Text("USED BY \(usage.joined(separator: " · ").uppercased()) · REMOVE IT FROM THE PLAN FIRST.")
                    .font(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.roundAccent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 44)
        }
    }

    // MARK: Loading and saving

    private func load() {
        guard let record else { return }
        name = record.movement.name
        loaded = true
    }

    private func draftMovement(from record: MovementRecord) -> Movement {
        var movement = record.movement
        movement.name = NameRules.movement(name)
        return movement
    }

    private func scheduleSave() {
        guard loaded, !isLocked, let record else { return }
        saveTask?.cancel()
        let movement = draftMovement(from: record)
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            record.apply(movement)
            try? context.save()
        }
    }

    private func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        guard loaded, let record else { return }
        record.apply(draftMovement(from: record))
        try? context.save()
    }

    private func close() {
        saveTask?.cancel()
        saveNow()
        dismiss()
    }
}
