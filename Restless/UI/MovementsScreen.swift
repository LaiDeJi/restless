import SwiftData
import SwiftUI

struct MovementsScreen: View {
    @Environment(SessionEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MovementRecord.createdAt) private var records: [MovementRecord]

    @State private var showRecording = false
    @State private var recordingMovementID: UUID?

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
                    Text(plural(records.count, "MOVEMENT", "MOVEMENTS"))
                        .font(Theme.TypeScale.body)
                        .foregroundStyle(Theme.secondaryText)

                    if isLocked {
                        EditingLockBanner()
                    }

                    if records.isEmpty {
                        Text("No movements yet. Record one on the watch to create it.")
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

                    recordButton
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showRecording) {
            RecordingSheet(movementID: recordingMovementID)
        }
    }

    private var header: some View {
        HStack {
            PlanPillButton(title: "‹ SESSIONS") {
                dismiss()
            }

            Spacer()

            Button {
                startRecording(nil)
            } label: {
                Image(systemName: "plus")
                    .font(Theme.TypeScale.value)
                    .foregroundStyle(isLocked ? .white.opacity(0.18) : .white.opacity(0.75))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white.opacity(isLocked ? 0.03 : 0.07)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isLocked)
            .accessibilityLabel("Record movement")
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
            VStack(alignment: .leading, spacing: 4) {
                Text(movement.name)
                    .font(Theme.TypeScale.rowTitle)
                    .tracking(0.2)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(movement.movement.profile?.usesForearmSignal == true ? "PROFILE" : "NO PROFILE")
                    .font(Theme.TypeScale.meta)
                    .tracking(0.2)
                    .foregroundStyle(Theme.secondaryText)
            }

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

    private var recordButton: some View {
        Button {
            startRecording(nil)
        } label: {
            Text("+ RECORD MOVEMENT")
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
        .padding(.top, 8)
    }

    private func startRecording(_ id: UUID?) {
        guard !isLocked else { return }
        recordingMovementID = id
        showRecording = true
    }
}
