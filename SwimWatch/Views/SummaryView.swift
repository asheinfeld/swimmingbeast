import SwiftUI
import SwimCore
import SwimHealth

struct SummaryView: View {
    let session: any SwimSessionServing

    var body: some View {
        NavigationStack {
            Group {
                if session.state == .ending {
                    ProgressView("Saving to Health…")
                } else if let workout = session.completedWorkout {
                    WorkoutSummaryContent(workout: workout, unit: session.displayUnit)
                } else {
                    failure
                }
            }
            .navigationTitle("Summary")
            .toolbar {
                if session.state != .ending {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { session.reset() }
                    }
                }
            }
        }
    }

    private var failure: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                if case .failed(let message) = session.state {
                    Text(message).font(.footnote)
                }
                Text("\(session.lengths.count) lengths were recorded but the workout couldn't be saved. Check Health permissions in the Settings app.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WorkoutSummaryContent: View {
    let workout: SwimWorkout
    let unit: SwimUnit

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(SwimFormat.distance(workout.distance, unit: unit))
                    .font(.system(.title, design: .rounded).weight(.bold).monospacedDigit())
                    .foregroundStyle(.blue)

                SummaryRow(label: "Swim time", value: SwimFormat.duration(workout.swimmingDuration))
                SummaryRow(label: "Total time", value: SwimFormat.duration(workout.elapsedDuration))
                SummaryRow(label: "Avg pace", value: SwimFormat.pace(workout.averagePace, unit: unit))
                SummaryRow(label: "Lengths", value: "\(workout.lengths.count)")
                if let fastest = workout.fastestLength {
                    SummaryRow(label: "Fastest", value: "#\(fastest.index) · \(SwimFormat.split(fastest.duration))s")
                }

                if !workout.strokeMix.isEmpty {
                    Text("Stroke mix").font(.footnote).foregroundStyle(.secondary).padding(.top, 4)
                    StrokeMixBar(mix: workout.strokeMix)
                    ForEach(workout.strokeMix) { entry in
                        HStack {
                            Circle().fill(entry.stroke.tint).frame(width: 8, height: 8)
                            Text(entry.stroke.displayName).font(.footnote)
                            Spacer()
                            Text("\(entry.count) · \(SwimFormat.percent(entry.fraction))")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Group {
                    if workout.isSample {
                        SampleDataBadge()
                        Text("Simulated swim — not saved to Health.")
                    } else if workout.healthKitUUID != nil {
                        Label("Saved to Health", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                .font(.caption2)
                .padding(.top, 4)
            }
        }
    }
}

private struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.footnote)
    }
}

#Preview("Summary – sample data") {
    SummaryContentPreview()
}

private struct SummaryContentPreview: View {
    var body: some View {
        NavigationStack {
            WorkoutSummaryContent(workout: SampleData.first, unit: .meters)
                .navigationTitle("Summary")
        }
    }
}
