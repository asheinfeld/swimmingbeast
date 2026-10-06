import Charts
import SwiftUI
import SwimCore
import SwimHealth

struct WorkoutDetailView: View {
    let workoutID: SwimWorkout.ID

    @Environment(HistoryStore.self) private var store
    @AppStorage(SwimSettingsKey.displayUnits) private var unitsRaw = DisplayUnitPreference.matchPool.rawValue
    @State private var editing: Length?

    var body: some View {
        if let workout = store.workout(id: workoutID) {
            detail(workout)
        } else {
            ContentUnavailableView("Workout not found", systemImage: "questionmark.folder",
                                   description: Text("It may have been deleted from Health."))
        }
    }

    private func detail(_ workout: SwimWorkout) -> some View {
        let unit = (DisplayUnitPreference(rawValue: unitsRaw) ?? .matchPool).resolve(for: workout.poolLength)
        return List {
            Section {
                StatsGrid(workout: workout, unit: unit)
                if workout.isSample {
                    SampleDataBadge()
                }
            }

            if !workout.strokeMix.isEmpty {
                Section("Stroke mix") {
                    StrokeMixChart(mix: workout.strokeMix)
                }
            }

            Section {
                if workout.lengths.isEmpty {
                    Text("Health didn't record individual lengths for this workout.")
                        .foregroundStyle(.secondary)
                } else {
                    LengthTableHeader()
                    ForEach(workout.lengths) { length in
                        Button {
                            editing = length
                        } label: {
                            LengthTableRow(length: length, unit: unit, isFastest: length.id == workout.fastestLength?.id)
                        }
                        .tint(.primary)
                    }
                }
            } header: {
                Text("Lengths")
            } footer: {
                if !workout.lengths.isEmpty {
                    Text("Tap a length to correct its stroke. Corrections stay on this iPhone; time and distance come from Health.")
                }
            }
        }
        .navigationTitle(workout.startedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { length in
            NavigationStack {
                StrokePickerList(length: length) { style in
                    store.setStroke(style, lengthIndex: length.index, workoutID: workout.id)
                    editing = nil
                }
                .navigationTitle("Stroke")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editing = nil }
                    }
                    if length.isUserOverride, store.hasDetectedStroke(lengthIndex: length.index, workoutID: workout.id) {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Use Detected Stroke") {
                                store.setStroke(nil, lengthIndex: length.index, workoutID: workout.id)
                                editing = nil
                            }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

private struct StatsGrid: View {
    let workout: SwimWorkout
    let unit: SwimUnit

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
            GridRow {
                Stat(label: "Distance", value: SwimFormat.distance(workout.distance, unit: unit), emphasized: true)
                Stat(label: "Avg pace", value: SwimFormat.pace(workout.averagePace, unit: unit))
            }
            GridRow {
                Stat(label: "Swim time", value: SwimFormat.duration(workout.swimmingDuration))
                Stat(label: "Total time", value: SwimFormat.duration(workout.elapsedDuration))
            }
            GridRow {
                Stat(label: "Lengths", value: "\(workout.lengths.count)")
                Stat(label: "Pool", value: workout.poolPreset?.displayName
                     ?? SwimFormat.distance(workout.poolLength, unit: unit))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct Stat: View {
    let label: String
    let value: String
    var emphasized = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(emphasized ? .title2.weight(.bold).monospacedDigit() : .body.weight(.medium).monospacedDigit())
                .foregroundStyle(emphasized ? Color.blue : Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StrokeMixChart: View {
    let mix: [StrokeMixEntry]

    var body: some View {
        HStack(spacing: 20) {
            Chart(mix) { entry in
                SectorMark(
                    angle: .value("Lengths", entry.count),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(entry.stroke.tint)
            }
            .frame(width: 110, height: 110)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(mix) { entry in
                    HStack {
                        Circle().fill(entry.stroke.tint).frame(width: 10, height: 10)
                        Text(entry.stroke.displayName)
                        Spacer()
                        Text("\(SwimFormat.percent(entry.fraction)) · \(entry.count)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct LengthTableHeader: View {
    var body: some View {
        HStack {
            Text("#").frame(width: 32, alignment: .leading)
            Text("Stroke")
            Spacer()
            Text("Split").frame(width: 64, alignment: .trailing)
            Text("Pace").frame(width: 96, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}

private struct LengthTableRow: View {
    let length: Length
    let unit: SwimUnit
    let isFastest: Bool

    var body: some View {
        HStack {
            Text("\(length.index)")
                .monospacedDigit()
                .frame(width: 32, alignment: .leading)
            StrokeChip(stroke: length.stroke, source: length.strokeSource)
            if isFastest {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Fastest length")
            }
            Spacer()
            Text(SwimFormat.split(length.duration))
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)
            Text(SwimFormat.pace(length.splitPace, unit: unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to change the stroke")
    }
}

#Preview("Detail – sample data") {
    let store = HistoryStore(provider: SampleSwimHistory(), overrides: InMemoryStrokeOverrideStore())
    return NavigationStack { WorkoutDetailView(workoutID: SampleData.first.id) }
        .environment(store)
        .task { await store.refresh() }
}
