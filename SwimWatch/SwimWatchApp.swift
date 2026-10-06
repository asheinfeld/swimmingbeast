import SwiftData
import SwiftUI
import SwimCore
import SwimHealth

@main
struct SwimWatchApp: App {
    @State private var environment = WatchEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView(session: environment.session)
        }
        .modelContainer(environment.container)
    }
}

/// Builds the long-lived dependencies once per launch.
@MainActor
final class WatchEnvironment {
    let container: ModelContainer
    let session: any SwimSessionServing

    init() {
        let container: ModelContainer
        do {
            container = try SwimPersistence.makeContainer()
        } catch {
            // A corrupt store must not block swimming; overrides fall back to memory for this launch.
            container = try! SwimPersistence.makeContainer(inMemory: true)
        }
        self.container = container
        let overrideStore = SwiftDataStrokeOverrideStore(container: container)

        #if targetEnvironment(simulator)
        // The simulator can't detect laps or strokes, so it runs a clearly labeled simulated session.
        session = PreviewSwimSession(overrideStore: overrideStore)
        #else
        session = HealthKitSwimSession(overrideStore: overrideStore)
        #endif

        SwimConnectivity.shared.onDefaultPoolLengthReceived = { pool in
            UserDefaults.standard.set(pool.rawValue, forKey: SwimSettingsKey.defaultPoolLength)
        }
        SwimConnectivity.shared.activate()
    }
}

struct RootView: View {
    let session: any SwimSessionServing

    var body: some View {
        switch session.state {
        case .idle, .starting:
            SetupView(session: session)
        case .failed where session.lengths.isEmpty:
            SetupView(session: session)
        case .running, .paused:
            ActiveSessionView(session: session)
        case .ending, .ended, .failed:
            SummaryView(session: session)
        }
    }
}

extension SwimSessionServing {
    /// The watch always reads distance and pace in the pool's own unit.
    var displayUnit: SwimUnit { DisplayUnitPreference.matchPool.resolve(for: poolLength) }
}
