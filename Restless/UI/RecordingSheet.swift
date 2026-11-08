import SwiftData
import SwiftUI

struct RecordingSheet: View {
    let movementID: UUID?

    @Environment(\.modelContext) private var context
    @Environment(SessionEngine.self) private var engine
    @Environment(WatchLink.self) private var watchLink
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MovementRecord.createdAt) private var records: [MovementRecord]

    @State private var model = MovementRecordingViewModel(service: WatchRecordingService())
    @State private var name = "Untitled movement"
    @State private var loaded = false
    @State private var nameFieldFrame: CGRect = .zero
    @FocusState private var nameFocused: Bool

    private var record: MovementRecord? { records.first { $0.id == movementID } }
    private var isLocked: Bool { engine.snapshot.isLocked }
    private var isEditing: Bool { movementID != nil }

    init(movementID: UUID?) {
        self.movementID = movementID
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    kicker("RECORD")
                    Text(isEditing ? "RE-RECORD" : "NEW MOVEMENT")
                        .font(Theme.TypeScale.screenTitle)
                        .foregroundStyle(.white)

                    if isLocked {
                        EditingLockBanner()
                    }

                    switch model.phase {
                    case .idle:
                        idleContent
                    case .waiting:
                        waitingContent
                    case .received(let profile):
                        receivedContent(profile)
                    case .failed(let reason):
                        failedContent(reason)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .pageTapKeyboardDismiss(
            isFocused: nameFocused,
            fieldFrame: nameFieldFrame,
            coordinateSpace: "recordingSheet"
        ) {
            nameFocused = false
        }
        .onAppear { load() }
        .onChange(of: records.count) { _, _ in load() }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Text("‹ \(isEditing ? "MOVEMENT" : "LIBRARY")")
                    .font(Theme.TypeScale.compactAction)
                    .tracking(0.9)
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(.white.opacity(0.06)))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("DONE")
                    .font(Theme.TypeScale.compactAction.weight(.bold))
                    .tracking(1.0)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(.white))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func kicker(_ text: String) -> some View {
        Text(text)
            .font(Theme.TypeScale.section.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(Theme.secondaryText)
    }

    // MARK: Idle

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("The watch records 15 seconds of your movement in the background. You can put your wrist down.")
                .font(Theme.TypeScale.body)
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            watchStrip

            Button {
                Task { await model.start() }
            } label: {
                Text("START RECORDING")
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
    }

    private var watchStrip: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(watchLink.reachable ? Theme.setAccent : .white.opacity(0.22))
                .frame(width: 7, height: 7)
            Text(watchLink.reachable ? "WATCH READY" : "WATCH ASLEEP")
                .font(Theme.TypeScale.micro.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(watchLink.reachable ? Theme.setAccent : .white.opacity(0.55))
            Text(watchLink.reachable ? "KEEP IT OPEN" : "START, THEN OPEN THE WATCH")
                .font(Theme.TypeScale.micro)
                .tracking(0.4)
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.04))
        )
    }

    // MARK: Waiting

    private var waitingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                ProgressView().tint(Theme.setAccent)
                Text("WAITING FOR THE TRACE")
                    .font(Theme.TypeScale.micro.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.setAccent)
            }

            Text(
                "Keep the watch on your wrist. It records 15 seconds in the background "
                    + "and sends the trace automatically."
            )
                .font(Theme.TypeScale.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("After the window, the watch fetches the motion. This can take a few seconds.")
                .font(Theme.TypeScale.body)
                .foregroundStyle(Theme.secondaryText)

            Button {
                model.reset()
            } label: {
                Text("CANCEL")
                    .font(Theme.TypeScale.compactAction.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Received

    private func receivedContent(_ profile: MovementProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                Circle()
                    .fill(Theme.setAccent)
                    .frame(width: 7, height: 7)
                Text("TRACE RECEIVED")
                    .font(Theme.TypeScale.micro.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.setAccent)
            }

            TraceChart(trace: model.trace, axis: profile.axis)
            MovementProfileGrid(profile: profile)
            Text("PROFILE OK · THREE OR MORE STEADY CYCLES.")
                .font(Theme.TypeScale.meta)
                .foregroundStyle(Theme.secondaryText)

            kicker("NAME")
            TextField("Movement name", text: $name)
                .font(Theme.TypeScale.pageTitle)
                .foregroundStyle(.white)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($nameFocused)
                .disabled(isLocked)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named("recordingSheet"))
                } action: { frame in
                    nameFieldFrame = frame
                }
                .onChange(of: name) { _, value in
                    let capped = NameRules.live(value)
                    if capped != value { name = capped }
                }

            Button {
                save(profile)
            } label: {
                Text("SAVE MOVEMENT")
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

            Button {
                dismiss()
            } label: {
                Text("DISCARD")
                    .font(Theme.TypeScale.meta.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Failed

    private func failedContent(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                Circle()
                    .fill(Theme.roundAccent)
                    .frame(width: 7, height: 7)
                Text("RECORDING FAILED")
                    .font(Theme.TypeScale.micro.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.roundAccent)
            }

            Text(reason)
                .font(Theme.TypeScale.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await model.start() }
            } label: {
                Text("TRY AGAIN")
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

            Button {
                dismiss()
            } label: {
                Text("CANCEL")
                    .font(Theme.TypeScale.meta.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Actions

    private func load() {
        guard !loaded, let record else { return }
        loaded = true
        name = record.movement.name
    }

    private func save(_ profile: MovementProfile) {
        guard !isLocked else { return }
        let cleanName = NameRules.movement(name)
        if let record {
            var movement = record.movement
            movement.name = cleanName
            movement.profile = profile
            record.apply(movement)
        } else {
            MovementRepository.add(
                Movement(
                    name: cleanName,
                    profile: profile
                ),
                in: context
            )
        }
        try? context.save()
        dismiss()
    }
}
