import Foundation
import Observation
import SwimCore
import SwimHealth

/// iPhone source of truth for the history screens.
///
/// Merges three inputs: HealthKit pool swims (authoritative for time/distance), workouts handed off
/// from the watch that HealthKit hasn't synced yet, and optional labeled sample workouts. Local stroke
/// overrides are applied last, so the app always wins for stroke.
@MainActor
@Observable
final class HistoryStore {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var workouts: [SwimWorkout] = []

    var includeSamples = false {
        didSet { if oldValue != includeSamples { rebuild() } }
    }

    @ObservationIgnored private let provider: any SwimHistoryProviding
    @ObservationIgnored private let overrides: any StrokeOverrideStoring
    @ObservationIgnored private var healthWorkouts: [SwimWorkout] = []
    @ObservationIgnored private var handoffWorkouts: [SwimWorkout] = []

    init(provider: any SwimHistoryProviding, overrides: any StrokeOverrideStoring) {
        self.provider = provider
        self.overrides = overrides
    }

    func workout(id: SwimWorkout.ID) -> SwimWorkout? {
        workouts.first { $0.id == id }
    }

    func refresh() async {
        if workouts.isEmpty { phase = .loading }
        do {
            try await provider.requestAuthorization()
            healthWorkouts = try await provider.loadWorkouts(limit: 200)
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
        rebuild()
    }

    func requestAuthorization() async {
        do {
            try await provider.requestAuthorization()
            await refresh()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// A workout the watch just finished. Its overrides are persisted so they survive the
    /// HealthKit copy replacing this one on the next refresh.
    func ingestHandoff(_ workout: SwimWorkout) {
        overrides.setOverrides(workout.userOverrides, workoutKey: workout.overrideKey)
        handoffWorkouts.removeAll { $0.overrideKey == workout.overrideKey }
        handoffWorkouts.append(workout)
        rebuild()
    }

    /// Pass `nil` to drop the override and show the stroke Health detected.
    func setStroke(_ style: StrokeStyle?, lengthIndex: Int, workoutID: SwimWorkout.ID) {
        guard let workout = workout(id: workoutID) else { return }
        overrides.setOverride(style, lengthIndex: lengthIndex, workoutKey: workout.overrideKey)
        rebuild()
    }

    /// Whether a length has a stroke Health detected that an override is hiding.
    func hasDetectedStroke(lengthIndex: Int, workoutID: SwimWorkout.ID) -> Bool {
        guard let raw = rawWorkout(id: workoutID),
              let length = raw.lengths.first(where: { $0.index == lengthIndex })
        else { return false }
        return length.strokeSource == .healthKit
    }

    private func rawWorkout(id: SwimWorkout.ID) -> SwimWorkout? {
        (healthWorkouts + handoffWorkouts + SampleData.workouts).first { $0.id == id }
    }

    private func rebuild() {
        let healthKeys = Set(healthWorkouts.map(\.overrideKey))
        let pending = handoffWorkouts.filter { !healthKeys.contains($0.overrideKey) }
        let samples = includeSamples ? SampleData.workouts : []
        workouts = (healthWorkouts + pending + samples)
            .map { overrides.applyOverrides(to: $0) }
            .sorted { $0.startedAt > $1.startedAt }
    }
}
