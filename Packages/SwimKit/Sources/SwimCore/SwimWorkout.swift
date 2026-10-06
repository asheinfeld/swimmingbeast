import Foundation

public struct SwimWorkout: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var poolLength: Measurement<UnitLength>
    public var lengths: [Length]
    public var healthKitUUID: UUID?
    /// True for bundled sample workouts so the UI can label them.
    public var isSample: Bool

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        poolLength: Measurement<UnitLength>,
        lengths: [Length],
        healthKitUUID: UUID? = nil,
        isSample: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.poolLength = poolLength
        self.lengths = lengths
        self.healthKitUUID = healthKitUUID
        self.isSample = isSample
    }

    /// Key used to persist stroke overrides. HealthKit UUID when saved, otherwise the local id.
    public var overrideKey: String { (healthKitUUID ?? id).uuidString }

    public var distance: Measurement<UnitLength> {
        Measurement(value: poolLength.value * Double(lengths.count), unit: poolLength.unit)
    }

    /// Wall-clock time including rest.
    public var elapsedDuration: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }

    /// Time spent actually swimming lengths.
    public var swimmingDuration: TimeInterval { lengths.reduce(0) { $0 + $1.duration } }

    /// Average swimming speed across all lengths (rest excluded).
    public var averagePace: Measurement<UnitSpeed>? {
        Pace.speed(distance: distance, duration: swimmingDuration)
    }

    public var fastestLength: Length? {
        lengths.filter { $0.duration > 0 }.min { $0.duration < $1.duration }
    }

    /// Share of lengths per stroke, largest first. Fractions sum to 1 when there are lengths.
    public var strokeMix: [StrokeMixEntry] {
        StrokeMixEntry.mix(for: lengths)
    }

    public var poolPreset: PoolLength? { PoolLength(measurement: poolLength) }

    /// Sets a user stroke on one length. Returns false when the id is not in this workout.
    @discardableResult
    public mutating func overrideStroke(lengthId: Length.ID, style: StrokeStyle) -> Bool {
        guard let i = lengths.firstIndex(where: { $0.id == lengthId }) else { return false }
        lengths[i].stroke = style
        lengths[i].strokeSource = .user
        return true
    }

    /// User overrides keyed by length index, suitable for persistence.
    public var userOverrides: [Int: StrokeStyle] {
        Dictionary(
            lengths.filter(\.isUserOverride).map { ($0.index, $0.stroke) },
            uniquingKeysWith: { _, last in last }
        )
    }

    /// Applies persisted overrides (keyed by length index). The app wins for stroke;
    /// duration and distance stay as HealthKit recorded them.
    public func applyingOverrides(_ overrides: [Int: StrokeStyle]) -> SwimWorkout {
        guard !overrides.isEmpty else { return self }
        var copy = self
        for i in copy.lengths.indices {
            if let style = overrides[copy.lengths[i].index] {
                copy.lengths[i].stroke = style
                copy.lengths[i].strokeSource = .user
            }
        }
        return copy
    }
}

public struct StrokeMixEntry: Identifiable, Hashable, Sendable {
    public var stroke: StrokeStyle
    public var count: Int
    public var fraction: Double

    public var id: StrokeStyle { stroke }

    public static func mix(for lengths: [Length]) -> [StrokeMixEntry] {
        guard !lengths.isEmpty else { return [] }
        let counts = Dictionary(grouping: lengths, by: \.stroke).mapValues(\.count)
        let total = Double(lengths.count)
        return counts
            .map { StrokeMixEntry(stroke: $0.key, count: $0.value, fraction: Double($0.value) / total) }
            .sorted {
                $0.count != $1.count
                    ? $0.count > $1.count
                    : StrokeStyle.allCases.firstIndex(of: $0.stroke)! < StrokeStyle.allCases.firstIndex(of: $1.stroke)!
            }
    }
}
