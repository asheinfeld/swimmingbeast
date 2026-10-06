#if canImport(HealthKit) && (os(iOS) || os(watchOS))
import Foundation
import HealthKit
import Observation
import SwimCore

/// Live indoor pool swim backed by `HKWorkoutSession` + `HKLiveWorkoutBuilder`.
///
/// Length detection and stroke classification come from the system: during a pool swim the
/// builder collects one `.lap` workout event per length, tagged with `HKSwimmingStrokeStyle`.
/// The swimmer's corrections are kept on the `Length`s, written into the saved workout's
/// metadata, and persisted in the `StrokeOverrideStoring` store keyed by the HealthKit UUID.
@MainActor
@Observable
public final class HealthKitSwimSession: NSObject, SwimSessionServing {
    public private(set) var state: SwimSessionState = .idle
    public private(set) var poolLength: Measurement<UnitLength> = PoolLength.meters25.measurement
    public private(set) var startedAt: Date?
    public private(set) var lengths: [Length] = []
    public private(set) var heartRate: Double?
    public private(set) var completedWorkout: SwimWorkout?
    public let isSimulated = false

    @ObservationIgnored private let healthStore: HKHealthStore
    @ObservationIgnored private let overrideStore: (any StrokeOverrideStoring)?
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?

    public init(healthStore: HKHealthStore = HKHealthStore(), overrideStore: (any StrokeOverrideStoring)? = nil) {
        self.healthStore = healthStore
        self.overrideStore = overrideStore
        super.init()
    }

    public func requestAuthorization() async throws {
        try await SwimHealthTypes.requestAuthorization(healthStore)
    }

    public func start(poolLength: Measurement<UnitLength>) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw SwimSessionError.healthDataUnavailable }
        reset()
        state = .starting
        self.poolLength = poolLength

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .swimming
        configuration.locationType = .indoor
        configuration.swimmingLocationType = .pool
        configuration.lapLength = SwimHealthTypes.lapLengthQuantity(poolLength)

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            let start = Date()
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
            startedAt = start
            state = .running
        } catch {
            state = .failed(error.localizedDescription)
            session = nil
            builder = nil
            throw error
        }
    }

    public func pause() { session?.pause() }

    public func resume() { session?.resume() }

    public func elapsedTime(at date: Date) -> TimeInterval {
        builder?.elapsedTime(at: date) ?? 0
    }

    public func overrideStroke(lengthId: Length.ID, style: StrokeStyle) {
        guard let i = lengths.firstIndex(where: { $0.id == lengthId }) else { return }
        lengths[i].stroke = style
        lengths[i].strokeSource = .user
    }

    @discardableResult
    public func endAndSave() async throws -> SwimWorkout {
        guard state.isActive, let session, let builder else { throw SwimSessionError.notActive }
        state = .ending
        let end = Date()
        session.end()

        do {
            try await builder.endCollection(at: end)
            ingest(SwimHealthTypes.lapRecords(from: builder.workoutEvents))

            let overrides = Dictionary(
                lengths.filter(\.isUserOverride).map { ($0.index, $0.stroke) },
                uniquingKeysWith: { _, last in last }
            )
            if let encoded = StrokeOverrideMetadata.encode(overrides) {
                try await builder.addMetadata([StrokeOverrideMetadata.key: encoded])
            }

            let hkWorkout = try await builder.finishWorkout()
            let workout = SwimWorkout(
                id: hkWorkout?.uuid ?? UUID(),
                startedAt: startedAt ?? hkWorkout?.startDate ?? end,
                endedAt: hkWorkout?.endDate ?? end,
                poolLength: poolLength,
                lengths: lengths,
                healthKitUUID: hkWorkout?.uuid
            )
            overrideStore?.setOverrides(overrides, workoutKey: workout.overrideKey)
            completedWorkout = workout
            state = .ended
            self.session = nil
            self.builder = nil
            return workout
        } catch {
            state = .failed(error.localizedDescription)
            throw SwimSessionError.saveFailed(error.localizedDescription)
        }
    }

    public func reset() {
        if let session, state.isActive { session.end() }
        session = nil
        builder = nil
        state = .idle
        startedAt = nil
        lengths = []
        heartRate = nil
        completedWorkout = nil
    }

    fileprivate func ingest(_ laps: [LapRecord]) {
        lengths = LengthReconciler.reconcile(existing: lengths, laps: laps, poolLength: poolLength)
    }

    fileprivate func handle(_ sessionState: HKWorkoutSessionState) {
        switch sessionState {
        case .running where state == .paused || state == .starting:
            state = .running
        case .paused where state == .running:
            state = .paused
        default:
            break
        }
    }
}

extension HealthKitSwimSession: HKWorkoutSessionDelegate {
    nonisolated public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in self.handle(toState) }
    }

    nonisolated public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in self.state = .failed(message) }
    }
}

extension HealthKitSwimSession: HKLiveWorkoutBuilderDelegate {
    nonisolated public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        let laps = SwimHealthTypes.lapRecords(from: workoutBuilder.workoutEvents)
        Task { @MainActor in self.ingest(laps) }
    }

    nonisolated public func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let heartRateType = HKQuantityType(.heartRate)
        guard collectedTypes.contains(heartRateType),
              let quantity = workoutBuilder.statistics(for: heartRateType)?.mostRecentQuantity()
        else { return }
        let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        Task { @MainActor in self.heartRate = bpm }
    }
}
#endif
