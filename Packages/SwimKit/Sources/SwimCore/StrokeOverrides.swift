import Foundation

/// Local persistence for stroke corrections. HealthKit stays the source of truth for
/// time and distance; this store wins for stroke. Keys are `SwimWorkout.overrideKey`
/// and the 1-based length index (stable across HealthKit re-queries, unlike `Length.id`).
@MainActor
public protocol StrokeOverrideStoring: AnyObject {
    func overrides(forWorkoutKey key: String) -> [Int: StrokeStyle]
    /// Pass `nil` to clear an override and fall back to HealthKit's stroke.
    func setOverride(_ style: StrokeStyle?, lengthIndex: Int, workoutKey: String)
}

extension StrokeOverrideStoring {
    public func setOverrides(_ overrides: [Int: StrokeStyle], workoutKey: String) {
        for (index, style) in overrides {
            setOverride(style, lengthIndex: index, workoutKey: workoutKey)
        }
    }

    public func applyOverrides(to workout: SwimWorkout) -> SwimWorkout {
        workout.applyingOverrides(overrides(forWorkoutKey: workout.overrideKey))
    }
}

@MainActor
public final class InMemoryStrokeOverrideStore: StrokeOverrideStoring {
    private var storage: [String: [Int: StrokeStyle]] = [:]

    public init() {}

    public func overrides(forWorkoutKey key: String) -> [Int: StrokeStyle] {
        storage[key] ?? [:]
    }

    public func setOverride(_ style: StrokeStyle?, lengthIndex: Int, workoutKey: String) {
        storage[workoutKey, default: [:]][lengthIndex] = style
    }
}

/// Overrides made on the watch are also written into the HealthKit workout's metadata at save
/// time, so the iPhone sees them even if the WatchConnectivity handoff never arrives.
/// HealthKit metadata values must be strings/numbers/dates, so the map is stored as JSON text.
public enum StrokeOverrideMetadata {
    public static let key = "com.swimmingbeast.strokeOverrides"

    public static func encode(_ overrides: [Int: StrokeStyle]) -> String? {
        guard !overrides.isEmpty else { return nil }
        let stringKeyed = Dictionary(uniqueKeysWithValues: overrides.map { (String($0.key), $0.value.rawValue) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(stringKeyed) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(_ string: String?) -> [Int: StrokeStyle] {
        guard let data = string?.data(using: .utf8),
              let raw = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        var result: [Int: StrokeStyle] = [:]
        for (key, value) in raw {
            if let index = Int(key), let style = StrokeStyle(rawValue: value) {
                result[index] = style
            }
        }
        return result
    }
}

/// Wire format for the watch → iPhone "just finished" handoff.
public enum SwimWorkoutCoding {
    public static func encode(_ workout: SwimWorkout) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(workout)
    }

    public static func decode(_ data: Data) throws -> SwimWorkout {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(SwimWorkout.self, from: data)
    }
}
