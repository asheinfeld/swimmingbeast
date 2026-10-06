#if canImport(WatchConnectivity)
import Foundation
import Observation
import SwimCore
import WatchConnectivity

/// Optional watch ↔ iPhone channel.
/// - Watch → iPhone: the just-finished `SwimWorkout` (with stroke overrides) via `transferUserInfo`,
///   which queues and survives the phone app not running.
/// - iPhone → Watch: the default pool length via `updateApplicationContext` (latest value wins).
/// The iPhone still reads history from HealthKit; this only makes a new swim show up immediately.
@MainActor
@Observable
public final class SwimConnectivity: NSObject {
    public static let shared = SwimConnectivity()

    public private(set) var isActivated = false

    @ObservationIgnored public var onWorkoutReceived: ((SwimWorkout) -> Void)?
    @ObservationIgnored public var onDefaultPoolLengthReceived: ((PoolLength) -> Void)?

    private enum Key {
        static let workout = "workout"
        static let defaultPoolLength = "defaultPoolLength"
    }

    public func activate() {
        guard WCSession.isSupported(), !isActivated else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    public func send(workout: SwimWorkout) {
        guard WCSession.isSupported(), let data = try? SwimWorkoutCoding.encode(workout) else { return }
        WCSession.default.transferUserInfo([Key.workout: data])
    }

    public func send(defaultPoolLength: PoolLength) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext([Key.defaultPoolLength: defaultPoolLength.rawValue])
    }

    fileprivate func receive(workoutData: Data?, poolRaw: String?) {
        if let workoutData, let workout = try? SwimWorkoutCoding.decode(workoutData) {
            onWorkoutReceived?(workout)
        }
        if let poolRaw, let pool = PoolLength(rawValue: poolRaw) {
            onDefaultPoolLengthReceived?(pool)
        }
    }
}

extension SwimConnectivity: WCSessionDelegate {
    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let activated = activationState == .activated
        let poolRaw = session.receivedApplicationContext[Key.defaultPoolLength] as? String
        Task { @MainActor in
            self.isActivated = activated
            self.receive(workoutData: nil, poolRaw: poolRaw)
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let data = userInfo[Key.workout] as? Data
        Task { @MainActor in self.receive(workoutData: data, poolRaw: nil) }
    }

    nonisolated public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let poolRaw = applicationContext[Key.defaultPoolLength] as? String
        Task { @MainActor in self.receive(workoutData: nil, poolRaw: poolRaw) }
    }

    #if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
#endif
