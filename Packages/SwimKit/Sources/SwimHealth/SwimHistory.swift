import Foundation
import SwimCore
#if canImport(HealthKit) && (os(iOS) || os(watchOS))
import HealthKit
#endif

/// Read-only access to past pool swims for the iPhone history screen.
public protocol SwimHistoryProviding: Sendable {
    func requestAuthorization() async throws
    /// Most recent first. Overrides stored in workout metadata are already applied;
    /// local store overrides are applied by the caller.
    func loadWorkouts(limit: Int) async throws -> [SwimWorkout]
}

/// Returns the bundled SAMPLE workouts. Each is flagged `isSample` so the UI labels it.
public struct SampleSwimHistory: SwimHistoryProviding {
    public init() {}
    public func requestAuthorization() async throws {}
    public func loadWorkouts(limit: Int) async throws -> [SwimWorkout] {
        Array(SampleData.workouts.prefix(limit))
    }
}

#if canImport(HealthKit) && (os(iOS) || os(watchOS))
public struct HealthKitSwimHistory: SwimHistoryProviding, @unchecked Sendable {
    private let healthStore: HKHealthStore

    public init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    public func requestAuthorization() async throws {
        try await SwimHealthTypes.requestAuthorization(healthStore)
    }

    public func loadWorkouts(limit: Int) async throws -> [SwimWorkout] {
        guard HKHealthStore.isHealthDataAvailable() else { throw SwimSessionError.healthDataUnavailable }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForWorkouts(with: .swimming))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: limit
        )
        let results = try await descriptor.result(for: healthStore)
        return results.compactMap(Self.swimWorkout(from:))
    }

    /// Converts a HealthKit workout into a `SwimWorkout`, or nil if it isn't a pool swim.
    public static func swimWorkout(from workout: HKWorkout) -> SwimWorkout? {
        let metadata = workout.metadata ?? [:]
        let location = (metadata[HKMetadataKeySwimmingLocationType] as? NSNumber)?.intValue
        guard location == HKWorkoutSwimmingLocationType.pool.rawValue else { return nil }

        let poolLength = (metadata[HKMetadataKeyLapLength] as? HKQuantity)
            .map(SwimHealthTypes.lapLengthMeasurement)
            ?? PoolLength.meters25.measurement

        let lengths = LengthReconciler.reconcile(
            existing: [],
            laps: SwimHealthTypes.lapRecords(from: workout.workoutEvents),
            poolLength: poolLength
        )
        let base = SwimWorkout(
            id: workout.uuid,
            startedAt: workout.startDate,
            endedAt: workout.endDate,
            poolLength: poolLength,
            lengths: lengths,
            healthKitUUID: workout.uuid
        )
        return base.applyingOverrides(StrokeOverrideMetadata.decode(metadata[StrokeOverrideMetadata.key] as? String))
    }
}
#endif
