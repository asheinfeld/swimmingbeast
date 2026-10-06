import SwiftUI
import SwimCore
import SwimHealth

struct HistoryView: View {
    @Environment(HistoryStore.self) private var store
    @AppStorage(SwimSettingsKey.displayUnits) private var unitsRaw = DisplayUnitPreference.matchPool.rawValue
    @AppStorage(SwimSettingsKey.showSampleWorkouts) private var showSamples = PhoneDefaults.showSampleWorkouts

    private var units: DisplayUnitPreference { DisplayUnitPreference(rawValue: unitsRaw) ?? .matchPool }

    var body: some View {
        content
            .navigationTitle("Swims")
            .navigationDestination(for: SwimWorkout.ID.self) { id in
                WorkoutDetailView(workoutID: id)
            }
            .refreshable { await store.refresh() }
            .task {
                store.includeSamples = showSamples
                await store.refresh()
            }
            .onChange(of: showSamples) { _, newValue in
                store.includeSamples = newValue
            }
    }

    @ViewBuilder
    private var content: some View {
        if store.workouts.isEmpty {
            switch store.phase {
            case .idle, .loading:
                ProgressView("Loading swims from Health…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't read Health", systemImage: "heart.slash")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { Task { await store.refresh() } }
                        .buttonStyle(.borderedProminent)
                }
            case .loaded:
                ContentUnavailableView {
                    Label("No pool swims yet", systemImage: "figure.pool.swim")
                } description: {
                    Text("Start a swim in SwimmingBeast on Apple Watch. Pool swims recorded in Health show up here too.")
                }
            }
        } else {
            List {
                if case .failed(let message) = store.phase {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.workouts) { workout in
                            NavigationLink(value: workout.id) {
                                HistoryRow(workout: workout, unit: units.resolve(for: workout.poolLength))
                            }
                        }
                    }
                }
            }
        }
    }

    private var sections: [MonthSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.workouts) {
            calendar.dateInterval(of: .month, for: $0.startedAt)?.start ?? $0.startedAt
        }
        return grouped.keys.sorted(by: >).map { month in
            MonthSection(month: month, workouts: grouped[month] ?? [])
        }
    }
}

private struct MonthSection: Identifiable {
    let month: Date
    let workouts: [SwimWorkout]

    var id: Date { month }
    var title: String { month.formatted(.dateTime.month(.wide).year()) }
}

struct HistoryRow: View {
    let workout: SwimWorkout
    let unit: SwimUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(SwimFormat.distance(workout.distance, unit: unit))
                    .font(.title3.weight(.semibold).monospacedDigit())
                Spacer()
                Text(workout.startedAt.formatted(.dateTime.weekday(.abbreviated).day().hour().minute()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label(SwimFormat.duration(workout.elapsedDuration), systemImage: "timer")
                Label(SwimFormat.pace(workout.averagePace, unit: unit), systemImage: "speedometer")
                Text(workout.poolPreset?.displayName ?? SwimFormat.distance(workout.poolLength, unit: unit))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)

            if !workout.strokeMix.isEmpty {
                StrokeMixBar(mix: workout.strokeMix, height: 6)
            }
            if workout.isSample {
                SampleDataBadge()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("History – sample data") {
    let store = HistoryStore(provider: SampleSwimHistory(), overrides: InMemoryStrokeOverrideStore())
    return NavigationStack { HistoryView() }
        .environment(store)
}
