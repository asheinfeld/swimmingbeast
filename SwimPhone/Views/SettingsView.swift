import SwiftUI
import SwimCore
import SwimHealth

struct SettingsView: View {
    @Environment(HistoryStore.self) private var store
    @AppStorage(SwimSettingsKey.defaultPoolLength) private var poolRaw = PoolLength.meters25.rawValue
    @AppStorage(SwimSettingsKey.displayUnits) private var unitsRaw = DisplayUnitPreference.matchPool.rawValue
    @AppStorage(SwimSettingsKey.showSampleWorkouts) private var showSamples = PhoneDefaults.showSampleWorkouts

    var body: some View {
        Form {
            Section {
                Picker("Default pool", selection: $poolRaw) {
                    ForEach(PoolLength.allCases) { pool in
                        Text("\(pool.displayName) · \(pool.subtitle)").tag(pool.rawValue)
                    }
                }
                Picker("Units", selection: $unitsRaw) {
                    ForEach(DisplayUnitPreference.allCases) { units in
                        Text(units.displayName).tag(units.rawValue)
                    }
                }
            } header: {
                Text("Pool")
            } footer: {
                Text("The default pool is preselected on Apple Watch. \"Match pool\" shows yards for yard pools and meters otherwise.")
            }

            Section {
                Button("Request Health Access") {
                    Task { await store.requestAuthorization() }
                }
            } header: {
                Text("Health")
            } footer: {
                Text("SwimmingBeast reads and saves swimming workouts, distance, stroke counts and heart rate. To change access later, open the Health app › Profile › Apps › SwimmingBeast.")
            }

            Section {
                Toggle("Show sample workouts", isOn: $showSamples)
            } header: {
                Text("Sample data")
            } footer: {
                Text("Adds a few made-up swims, marked \"Sample data\", so you can explore the app without a recorded workout.")
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.appVersion)
                Text("Stroke corrections are stored on this device only. Health stays the source of truth for time and distance.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .onChange(of: poolRaw) { _, newValue in
            if let pool = PoolLength(rawValue: newValue) {
                SwimConnectivity.shared.send(defaultPoolLength: pool)
            }
        }
    }
}

private extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(HistoryStore(provider: SampleSwimHistory(), overrides: InMemoryStrokeOverrideStore()))
}
