import Foundation

/// One pool length (wall to wall). HealthKit calls these "laps".
public struct Length: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// 1-based position within the workout.
    public var index: Int
    public var duration: TimeInterval
    public var stroke: StrokeStyle
    public var strokeSource: StrokeSource
    public var splitPace: Measurement<UnitSpeed>?
    /// Start of the length; used to match HealthKit lap events across updates.
    public var startedAt: Date?

    public init(
        id: UUID = UUID(),
        index: Int,
        duration: TimeInterval,
        stroke: StrokeStyle,
        strokeSource: StrokeSource = .healthKit,
        splitPace: Measurement<UnitSpeed>? = nil,
        startedAt: Date? = nil
    ) {
        self.id = id
        self.index = index
        self.duration = duration
        self.stroke = stroke
        self.strokeSource = strokeSource
        self.splitPace = splitPace
        self.startedAt = startedAt
    }

    /// Builds a length and derives its split pace from the pool length.
    public init(
        id: UUID = UUID(),
        index: Int,
        duration: TimeInterval,
        stroke: StrokeStyle,
        strokeSource: StrokeSource = .healthKit,
        poolLength: Measurement<UnitLength>,
        startedAt: Date? = nil
    ) {
        self.init(
            id: id,
            index: index,
            duration: duration,
            stroke: stroke,
            strokeSource: strokeSource,
            splitPace: Pace.speed(distance: poolLength, duration: duration),
            startedAt: startedAt
        )
    }

    public var isUserOverride: Bool { strokeSource == .user }
}
