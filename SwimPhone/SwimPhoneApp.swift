import SwiftData
import SwiftUI
import SwimCore
import SwimHealth

@main
struct SwimPhoneApp: App {
    @State private var environment = PhoneEnvironment()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(environment.history)
        }
        .modelContainer(environment.container)
    }
}

@MainActor
final class PhoneEnvironment {
    let container: ModelContainer
    let history: HistoryStore

    init() {
        let container: ModelContainer
        do {
            container = try SwimPersistence.makeContainer()
        } catch {
            container = try! SwimPersistence.makeContainer(inMemory: true)
        }
        self.container = container
        history = HistoryStore(
            provider: HealthKitSwimHistory(),
            overrides: SwiftDataStrokeOverrideStore(container: container)
        )

        let store = history
        SwimConnectivity.shared.onWorkoutReceived = { workout in
            store.ingestHandoff(workout)
        }
        SwimConnectivity.shared.activate()
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "list.bullet.rectangle") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

enum PhoneDefaults {
    /// Samples default on in the simulator, where Health has no swims, and off on devices.
    static var showSampleWorkouts: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}
