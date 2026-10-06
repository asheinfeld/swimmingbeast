import Foundation

public enum StrokeStyle: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case freestyle
    case backstroke
    case breaststroke
    case butterfly
    case mixed
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .freestyle: "Freestyle"
        case .backstroke: "Backstroke"
        case .breaststroke: "Breaststroke"
        case .butterfly: "Butterfly"
        case .mixed: "Mixed"
        case .unknown: "Unknown"
        }
    }

    public var shortName: String {
        switch self {
        case .freestyle: "Free"
        case .backstroke: "Back"
        case .breaststroke: "Breast"
        case .butterfly: "Fly"
        case .mixed: "Mixed"
        case .unknown: "—"
        }
    }

    /// Strokes offered when the swimmer corrects a length. `.unknown` is never a useful correction.
    public static let userSelectable: [StrokeStyle] = [.freestyle, .backstroke, .breaststroke, .butterfly, .mixed]

    /// Maps the raw value of `HKSwimmingStrokeStyle` without importing HealthKit.
    /// 0 unknown, 1 mixed, 2 freestyle, 3 backstroke, 4 breaststroke, 5 butterfly, 6 kickboard (watchOS 10+).
    /// We have no kickboard case, so kick sets surface as `.unknown` for the swimmer to relabel.
    public init(healthKitRawValue: Int?) {
        switch healthKitRawValue {
        case 1: self = .mixed
        case 2: self = .freestyle
        case 3: self = .backstroke
        case 4: self = .breaststroke
        case 5: self = .butterfly
        default: self = .unknown
        }
    }

    public var healthKitRawValue: Int {
        switch self {
        case .unknown: 0
        case .mixed: 1
        case .freestyle: 2
        case .backstroke: 3
        case .breaststroke: 4
        case .butterfly: 5
        }
    }
}

public enum StrokeSource: String, Codable, Hashable, Sendable {
    case healthKit
    case user
}
