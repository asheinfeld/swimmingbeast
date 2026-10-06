import Foundation

/// Hand-written SAMPLE workouts for SwiftUI previews, the simulator, and the optional
/// "Show sample workouts" setting. Every workout here has `isSample == true` and the UI
/// labels it as sample data. Never mix these into real HealthKit history silently.
public enum SampleData {
    public static let workouts: [SwimWorkout] = [
        make(
            daysAgo: 1,
            pool: .meters25,
            // 4×100 free, 4×50 back, 100 IM-ish
            plan: Array(repeating: (StrokeStyle.freestyle, 24.0), count: 16)
                + Array(repeating: (StrokeStyle.backstroke, 28.5), count: 8)
                + [(.butterfly, 27.0), (.backstroke, 29.0), (.breaststroke, 33.0), (.freestyle, 25.0)],
            overriddenIndices: [26],
            idSuffix: 1
        ),
        make(
            daysAgo: 3,
            pool: .yards25,
            plan: Array(repeating: (StrokeStyle.freestyle, 21.0), count: 20)
                + Array(repeating: (StrokeStyle.breaststroke, 30.0), count: 6),
            overriddenIndices: [],
            idSuffix: 2
        ),
        make(
            daysAgo: 6,
            pool: .meters50,
            plan: Array(repeating: (StrokeStyle.freestyle, 52.0), count: 10)
                + [(.mixed, 60.0), (.unknown, 58.0)],
            overriddenIndices: [],
            idSuffix: 3
        ),
    ]

    public static var first: SwimWorkout { workouts[0] }

    /// A short in-progress list for live-session previews.
    public static func lengths(count: Int, pool: PoolLength = .meters25, start: Date = .now) -> [Length] {
        let rotation: [StrokeStyle] = [.freestyle, .freestyle, .backstroke, .breaststroke, .butterfly]
        var cursor = start
        return (0..<count).map { i in
            let duration = 22.0 + Double(i % 4) * 1.5
            defer { cursor = cursor.addingTimeInterval(duration + 5) }
            return Length(
                index: i + 1,
                duration: duration,
                stroke: rotation[i % rotation.count],
                strokeSource: .healthKit,
                poolLength: pool.measurement,
                startedAt: cursor
            )
        }
    }

    private static func make(
        daysAgo: Int,
        pool: PoolLength,
        plan: [(StrokeStyle, TimeInterval)],
        overriddenIndices: Set<Int>,
        idSuffix: Int
    ) -> SwimWorkout {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: today)!.addingTimeInterval(6.5 * 3600)
        let rest: TimeInterval = 10
        var cursor = start
        let lengths: [Length] = plan.enumerated().map { offset, step in
            let index = offset + 1
            let length = Length(
                id: UUID(uuidString: String(format: "00000000-0000-0000-%04d-%012d", idSuffix, index))!,
                index: index,
                duration: step.1,
                stroke: step.0,
                strokeSource: overriddenIndices.contains(index) ? .user : .healthKit,
                poolLength: pool.measurement,
                startedAt: cursor
            )
            cursor = cursor.addingTimeInterval(step.1 + rest)
            return length
        }
        return SwimWorkout(
            id: UUID(uuidString: String(format: "5A3B1E00-0000-0000-0000-%012d", idSuffix))!,
            startedAt: start,
            endedAt: cursor,
            poolLength: pool.measurement,
            lengths: lengths,
            healthKitUUID: nil,
            isSample: true
        )
    }
}
