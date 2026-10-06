import Foundation

public enum Pace {
    public static func speed(distance: Measurement<UnitLength>, duration: TimeInterval) -> Measurement<UnitSpeed>? {
        guard duration > 0, distance.value > 0 else { return nil }
        let metersPerSecond = distance.converted(to: .meters).value / duration
        return Measurement(value: metersPerSecond, unit: .metersPerSecond)
    }

    /// Seconds to swim 100 of `unit` at `speed` — how swimmers read pace (e.g. 1:45 /100m).
    public static func secondsPer100(_ speed: Measurement<UnitSpeed>, unit: SwimUnit) -> TimeInterval? {
        let metersPerSecond = speed.converted(to: .metersPerSecond).value
        guard metersPerSecond > 0 else { return nil }
        let hundredInMeters = Measurement(value: 100, unit: unit.unitLength).converted(to: .meters).value
        return hundredInMeters / metersPerSecond
    }
}

/// Locale-independent formatting so the watch and phone render identical numbers.
public enum SwimFormat {
    /// "0:32", "1:05:12"
    public static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let total = Int(seconds.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// "32.4" — length splits are short enough that tenths matter.
    public static func split(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--" }
        if seconds < 60 { return String(format: "%.1f", seconds) }
        let m = Int(seconds) / 60
        let s = seconds - Double(m * 60)
        return String(format: "%d:%04.1f", m, s)
    }

    /// "1:45 /100m"
    public static func pace(_ speed: Measurement<UnitSpeed>?, unit: SwimUnit) -> String {
        guard let speed, let seconds = Pace.secondsPer100(speed, unit: unit) else { return "--:-- /100\(unit.symbol)" }
        let rounded = seconds.rounded()
        return "\(duration(rounded)) /100\(unit.symbol)"
    }

    /// "1,250 m" — always whole units; pools are measured in whole meters or yards.
    public static func distance(_ distance: Measurement<UnitLength>, unit: SwimUnit) -> String {
        let value = distance.converted(to: unit.unitLength).value.rounded()
        return "\(grouped(Int(value))) \(unit.symbol)"
    }

    public static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    private static func grouped(_ value: Int) -> String {
        let digits = String(abs(value))
        var out = ""
        for (i, ch) in digits.reversed().enumerated() {
            if i > 0, i % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return (value < 0 ? "-" : "") + String(out.reversed())
    }
}
