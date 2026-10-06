import Foundation

/// The pool sizes v1 supports. Workouts store the underlying `Measurement` so history
/// read from HealthKit (which may contain other lap lengths) still round-trips.
public enum PoolLength: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case yards25
    case meters25
    case meters50

    public var id: String { rawValue }

    public var measurement: Measurement<UnitLength> {
        switch self {
        case .yards25: Measurement(value: 25, unit: .yards)
        case .meters25: Measurement(value: 25, unit: .meters)
        case .meters50: Measurement(value: 50, unit: .meters)
        }
    }

    public var displayName: String {
        switch self {
        case .yards25: "25 yd"
        case .meters25: "25 m"
        case .meters50: "50 m"
        }
    }

    public var subtitle: String {
        switch self {
        case .yards25: "Short course yards"
        case .meters25: "Short course meters"
        case .meters50: "Long course / Olympic"
        }
    }

    public var naturalUnit: SwimUnit { self == .yards25 ? .yards : .meters }

    public init?(measurement: Measurement<UnitLength>) {
        let match = Self.allCases.first {
            $0.measurement.unit == measurement.unit
                && abs($0.measurement.value - measurement.value) < 0.01
        }
        if let match {
            self = match
            return
        }
        let meters = measurement.converted(to: .meters).value
        guard let byValue = Self.allCases.first(where: {
            abs($0.measurement.converted(to: .meters).value - meters) < 0.05
        }) else { return nil }
        self = byValue
    }
}

/// The unit a swimmer reads distance and pace in.
public enum SwimUnit: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case meters
    case yards

    public var id: String { rawValue }
    public var unitLength: UnitLength { self == .meters ? .meters : .yards }
    public var symbol: String { self == .meters ? "m" : "yd" }
    public var displayName: String { self == .meters ? "Meters" : "Yards" }
}

/// iPhone display preference. `matchPool` shows each workout in its own pool's unit.
public enum DisplayUnitPreference: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case matchPool
    case meters
    case yards

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .matchPool: "Match pool"
        case .meters: "Meters"
        case .yards: "Yards"
        }
    }

    public func resolve(for poolLength: Measurement<UnitLength>) -> SwimUnit {
        switch self {
        case .meters: .meters
        case .yards: .yards
        case .matchPool: poolLength.unit == UnitLength.yards ? .yards : .meters
        }
    }
}

/// UserDefaults keys shared by both apps.
public enum SwimSettingsKey {
    public static let defaultPoolLength = "defaultPoolLength"
    public static let displayUnits = "displayUnits"
    public static let showSampleWorkouts = "showSampleWorkouts"
}
