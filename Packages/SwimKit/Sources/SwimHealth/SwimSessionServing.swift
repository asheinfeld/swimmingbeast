import Foundation
import Observation
import SwimCore

public enum SwimSessionState: Equatable, Sendable {
    case idle
    case starting
    case running
    case paused
    case ending
    case ended
    case failed(String)

    public var isActive: Bool { self == .running || self == .paused }
}

public enum SwimSessionError: LocalizedError, Equatable {
    case healthDataUnavailable
    case notActive
    case saveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .healthDataUnavailable: "Health data isn't available on this device."
        case .notActive: "There's no swim in progress."
        case .saveFailed(let reason): "Couldn't save to Health: \(reason)"
        }
    }
}

/// The live pool-swim session the watch UI talks to. `HealthKitSwimSession` is the real
/// implementation; `PreviewSwimSession` simulates one for previews, the simulator and tests.
@MainActor
public protocol SwimSessionServing: AnyObject, Observable {
    var state: SwimSessionState { get }
    var poolLength: Measurement<UnitLength> { get }
    var startedAt: Date? { get }
    /// Lengths so far, oldest first.
    var lengths: [Length] { get }
    /// Most recent heart rate in BPM, if the sensor has reported one.
    var heartRate: Double? { get }
    /// Set after a successful `endAndSave()`.
    var completedWorkout: SwimWorkout? { get }
    /// True when the numbers on screen are generated, not measured. The UI must label them.
    var isSimulated: Bool { get }

    func requestAuthorization() async throws
    func start(poolLength: Measurement<UnitLength>) async throws
    func pause()
    func resume()
    /// Active time excluding pauses.
    func elapsedTime(at date: Date) -> TimeInterval
    func overrideStroke(lengthId: Length.ID, style: StrokeStyle)
    @discardableResult
    func endAndSave() async throws -> SwimWorkout
    /// Returns to `.idle` after the summary is dismissed.
    func reset()
}

extension SwimSessionServing {
    public var distance: Measurement<UnitLength> {
        Measurement(value: poolLength.value * Double(lengths.count), unit: poolLength.unit)
    }

    public var lastLength: Length? { lengths.last }
}
