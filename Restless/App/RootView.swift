import Combine
import SwiftUI

struct RootView: View {
    @Environment(SessionEngine.self) private var engine
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
            if phase == .active { engine.refreshFromStore() }
        }
        .onOpenURL { url in
            router.showTimer()
            engine.handle(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .countdownAlertOpened)) { _ in
            router.showTimer()
            engine.refreshFromStore()
        }
        .task {
            engine.setActive(scenePhase == .active)
        }
    }
}
