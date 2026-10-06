#if canImport(HealthKit) && (os(iOS) || os(watchOS))
import Foundation
import HealthKit
import SwimCore

public enum SwimHealthTypes {
    public static let share: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.distanceSwimming),
        HKQuantityType(.swimmingStrokeCount),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
    ]

    public static let read: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.distanceSwimming),
        HKQuantityType(.swimmingStrokeCount),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
    ]

    public static func requestAuthorization(_ store: HKHealthStore) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw SwimSessionError.healthDataUnavailable }
        try await store.requestAuthorization(toShare: share, read: read)
    }

    public static func lapLengthQuantity(_ length: Measurement<UnitLength>) -> HKQuantity {
        length.unit == UnitLength.yards
            ? HKQuantity(unit: .yard(), doubleValue: length.value)
            : HKQuantity(unit: .meter(), doubleValue: length.converted(to: .meters).value)
    }

    public static func lapLengthMeasurement(_ quantity: HKQuantity) -> Measurement<UnitLength> {
        if quantity.is(compatibleWith: .yard()) {
            let yards = quantity.doubleValue(for: .yard())
            if abs(yards - yards.rounded()) < 0.01 {
                return Measurement(value: yards.rounded(), unit: .yards)
            }
        }
        return Measurement(value: quantity.doubleValue(for: .meter()), unit: .meters)
    }

    /// Lap events reduced to plain values. Pool swims emit one `.lap` event per length,
    /// carrying `HKMetadataKeySwimmingStrokeStyle`.
    static func lapRecords(from events: [HKWorkoutEvent]?) -> [LapRecord] {
        (events ?? [])
            .filter { $0.type == .lap }
            .map { event in
                let raw = (event.metadata?[HKMetadataKeySwimmingStrokeStyle] as? NSNumber)?.intValue
                return LapRecord(
                    start: event.dateInterval.start,
                    duration: event.dateInterval.duration,
                    stroke: StrokeStyle(healthKitRawValue: raw)
                )
            }
    }
}

extension StrokeStyle {
    public init(_ hkStyle: HKSwimmingStrokeStyle) {
        self.init(healthKitRawValue: hkStyle.rawValue)
    }
}
#endif
