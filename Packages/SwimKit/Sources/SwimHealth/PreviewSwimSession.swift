import Foundation
import Observation
import SwimCore

/// A simulated session: it generates SAMPLE lengths on a timer instead of reading sensors.
/// Used for SwiftUI previews and the watch simulator (which can't detect swimming).
/// `isSimulated` is always true so screens show a "Sample data" badge.
@MainActor
@Observable
public final class PreviewSwimSession: SwimSessionServing {
    public private(set) var state: SwimSessionState
    public private(set) var poolLength: Measurement<UnitLength>
    public private(set) var startedAt: Date?
    public private(set) var lengths: [Length]
    public private(set) var heartRate: Double?
    public private(set) var completedWorkout: SwimWorkout?
    public let isSimulated = true

    @ObservationIgnored private let lengthInterval: TimeInterval
    @ObservationIgnored private let autoGenerate: Bool
    @ObservationIgnored private let overrideStore: (any StrokeOverrideStoring)?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var pausedAccumulated: TimeInterval = 0
    @ObservationIgnored private var pausedAt: Date?

    /// - Parameters:
    ///   - lengthInterval: Seconds between generated lengths. Short by default so the simulator shows progress quickly.
    ///   - autoGenerate: Set false for static previews and tests.
    public init(
        state: SwimSessionState = .idle,
        poolLength: PoolLength = .meters25,
        lengths: [Length] = [],
        lengthInterval: TimeInterval = 6,
        autoGenerate: Bool = true,
        overrideStore: (any StrokeOverrideStoring)? = nil
    ) {
        self.state = state
        self.poolLength = poolLength.measurement
        self.lengths = lengths
        self.lengthInterval = lengthInterval
        self.overrideStore = overrideStore
        self.autoGenerate = autoGenerate
        if state.isActive {
            startedAt = lengths.first?.startedAt ?? Date()
            heartRate = lengths.isEmpty ? nil : 128
            if autoGenerate, state == .running { startTicker() }
        }
    }

    public func requestAuthorization() async throws {}

    public func start(poolLength: Measurement<UnitLength>) async throws {
        reset()
        self.poolLength = poolLength
        startedAt = Date()
        state = .running
        if autoGenerate { startTicker() }
    }

    public func pause() {
        guard state == .running else { return }
        pausedAt = Date()
        state = .paused
    }

    public func resume() {
        guard state == .paused else { return }
        if let pausedAt { pausedAccumulated += Date().timeIntervalSince(pausedAt) }
        pausedAt = nil
        state = .running
    }

    public func elapsedTime(at date: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        let end = pausedAt ?? date
        return max(0, end.timeIntervalSince(startedAt) - pausedAccumulated)
    }

    public func overrideStroke(lengthId: Length.ID, style: StrokeStyle) {
        guard let i = lengths.firstIndex(where: { $0.id == lengthId }) else { return }
        lengths[i].stroke = style
        lengths[i].strokeSource = .user
    }

    /// Appends one generated length. Exposed so tests and previews can drive the session deterministically.
    public func simulateLength(duration: TimeInterval? = nil, stroke: StrokeStyle? = nil) {
        let rotation: [StrokeStyle] = [.freestyle, .freestyle, .freestyle, .backstroke, .breaststroke, .butterfly]
        let index = lengths.count + 1
        let split = duration ?? (21 + Double(index % 5) * 1.3)
        lengths.append(
            Length(
                index: index,
                duration: split,
                stroke: stroke ?? rotation[(index - 1) % rotation.count],
                strokeSource: .healthKit,
                poolLength: poolLength,
                startedAt: Date().addingTimeInterval(-split)
            )
        )
        heartRate = 118 + Double(index % 7) * 3
    }

    @discardableResult
    public func endAndSave() async throws -> SwimWorkout {
        guard state.isActive, let startedAt else { throw SwimSessionError.notActive }
        ticker?.cancel()
        state = .ending
        let workout = SwimWorkout(
            startedAt: startedAt,
            endedAt: Date(),
            poolLength: poolLength,
            lengths: lengths,
            healthKitUUID: nil,
            isSample: true
        )
        overrideStore?.setOverrides(workout.userOverrides, workoutKey: workout.overrideKey)
        completedWorkout = workout
        state = .ended
        return workout
    }

    public func reset() {
        ticker?.cancel()
        ticker = nil
        state = .idle
        startedAt = nil
        lengths = []
        heartRate = nil
        completedWorkout = nil
        pausedAccumulated = 0
        pausedAt = nil
    }

    private func startTicker() {
        ticker?.cancel()
        let interval = lengthInterval
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard let self, !Task.isCancelled else { return }
                if self.state == .running { self.simulateLength() }
            }
        }
    }
}
