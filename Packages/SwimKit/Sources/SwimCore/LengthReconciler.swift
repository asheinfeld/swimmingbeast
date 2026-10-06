import Foundation

/// A HealthKit lap event reduced to plain values, so reconciliation can be tested without HealthKit.
public struct LapRecord: Hashable, Sendable {
    public var start: Date
    public var duration: TimeInterval
    public var stroke: StrokeStyle

    public init(start: Date, duration: TimeInterval, stroke: StrokeStyle) {
        self.start = start
        self.duration = duration
        self.stroke = stroke
    }
}

public enum LengthReconciler {
    /// Rebuilds the length list from the full set of lap events the builder has collected.
    ///
    /// HealthKit can deliver the event list repeatedly and may refine a lap's stroke after the fact,
    /// so this is idempotent: existing lengths keep their `id` (the UI and overrides reference it),
    /// HealthKit values refresh, and any user override survives.
    public static func reconcile(
        existing: [Length],
        laps: [LapRecord],
        poolLength: Measurement<UnitLength>
    ) -> [Length] {
        let sorted = laps.sorted { $0.start < $1.start }
        var byStart: [Date: Length] = [:]
        for length in existing {
            if let start = length.startedAt { byStart[start] = length }
        }

        return sorted.enumerated().map { offset, lap in
            let previous = byStart[lap.start]
            let isUser = previous?.strokeSource == .user
            return Length(
                id: previous?.id ?? UUID(),
                index: offset + 1,
                duration: lap.duration,
                stroke: isUser ? previous!.stroke : lap.stroke,
                strokeSource: isUser ? .user : .healthKit,
                poolLength: poolLength,
                startedAt: lap.start
            )
        }
    }
}
