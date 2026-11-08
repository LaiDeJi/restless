import Foundation
import Observation

enum AppTab: Hashable {
    case timer
    case sessions
}

enum SessionRoute: Hashable {
    /// A saved session, opened in the editor's existing mode.
    case session(UUID)
    /// An unsaved draft built by the SESSIONS add control.
    case newSession(WorkoutPreset)
}

@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .timer
    var sessionsPath: [SessionRoute] = []

    /// The timer's EDIT action: show the active session in the sessions tab.
    func openActiveSession(_ id: UUID) {
        tab = .sessions
        sessionsPath = [.session(id)]
    }

    func showTimer() {
        tab = .timer
    }

    func showSessionsList() {
        tab = .sessions
        sessionsPath.removeAll()
    }
}
