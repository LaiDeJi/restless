import SwiftUI

struct RootView: View {
    @Environment(SessionEngine.self) private var engine
    @Environment(WatchLink.self) private var watchLink
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
        }
        .tint(Theme.setAccent)
        .toolbarBackground(Theme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .preferredColorScheme(.dark)
        .environment(router)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { engine.refreshFromStore() }
        }
        .onOpenURL { url in
            router.showTimer()
            engine.handle(url)
        }
        .task {
            watchLink.onComplete = { [engine] in
                engine.perform(.setDone)
            }
        }
    }
}
