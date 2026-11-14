import Combine
import SwiftData
import SwiftUI
import UIKit

struct RootView: View {
    @Environment(SessionEngine.self) private var engine
    @Environment(CalendarSettingsModel.self) private var calendarSettings
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var router = AppRouter()

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.tab) {
            TimerScreen()
                .tabItem { Label("TIMER", systemImage: "timer") }
                .tag(AppTab.timer)

            NavigationStack(path: $router.sessionsPath) {
                SessionsScreen()
                    .navigationDestination(for: SessionRoute.self) { route in
                        switch route {
                        case .session(let id):
                            SessionEditorScreen(mode: .existing(id))
                        case .newSession(let preset):
                            SessionEditorScreen(mode: .draft(preset))
                        }
                    }
            }
            .tabItem { Label("SESSIONS", systemImage: "list.bullet.rectangle") }
            .tag(AppTab.sessions)

            NavigationStack(path: $router.calendarPath) {
                CalendarScreen()
                    .navigationDestination(for: CalendarRoute.self) { route in
                        switch route {
                        case .exceptions:
                            ExceptionsScreen()
                        }
                    }
            }
            .tabItem { Label("CALENDAR", systemImage: "calendar") }
            .tag(AppTab.calendar)
        }
        .tint(Theme.setAccent)
        .toolbarBackground(Theme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .preferredColorScheme(.dark)
        .environment(router)
        .onChange(of: scenePhase) { _, phase in
            engine.setActive(phase == .active)
            if phase == .active {
                // Restore a Live Activity intent before deciding, so a running
                // session the intent advanced is not mistaken for a stale gate.
                engine.refreshFromStore()
                followPlan()
            }
        }
        .onOpenURL { url in
            router.showTimer()
            engine.handle(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .countdownAlertOpened)) { _ in
            router.showTimer()
            engine.refreshFromStore()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            followPlan()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            followPlan()
        }
        .task {
            engine.setActive(scenePhase == .active)
            followPlan()
        }
    }

    /// The timer follows the session the calendar plans for today, unless the
    /// session is running or was picked by hand today.
    private func followPlan() {
        ActiveSessionFollower.follow(
            today: .now,
            calendar: .current,
            context: context,
            calendarSettings: calendarSettings,
            engine: engine
        )
    }
}
