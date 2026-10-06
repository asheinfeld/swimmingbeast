import SwiftUI
import SwimCore

extension StrokeStyle {
    var tint: Color {
        switch self {
        case .freestyle: .blue
        case .backstroke: .teal
        case .breaststroke: .green
        case .butterfly: .purple
        case .mixed: .orange
        case .unknown: .gray
        }
    }
}

/// Capsule label for a stroke. A pencil marks strokes the swimmer corrected.
struct StrokeChip: View {
    let stroke: StrokeStyle
    var source: StrokeSource = .healthKit
    var compact = false

    var body: some View {
        HStack(spacing: 3) {
            Text(compact ? stroke.shortName : stroke.displayName)
            if source == .user {
                Image(systemName: "pencil")
                    .imageScale(.small)
                    .accessibilityLabel("Edited")
            }
        }
        .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, 3)
        .foregroundStyle(stroke.tint)
        .background(stroke.tint.opacity(0.18), in: Capsule())
    }
}

/// Horizontal stacked bar of the stroke mix.
struct StrokeMixBar: View {
    let mix: [StrokeMixEntry]
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 1) {
                ForEach(mix) { entry in
                    entry.stroke.tint
                        .frame(width: max(2, proxy.size.width * entry.fraction - 1))
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .accessibilityElement()
        .accessibilityLabel(
            mix.map { "\($0.stroke.displayName) \(SwimFormat.percent($0.fraction))" }.joined(separator: ", ")
        )
    }
}

/// Shown wherever numbers are simulated or bundled samples rather than measured.
struct SampleDataBadge: View {
    var body: some View {
        Label("Sample data", systemImage: "flask")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(.yellow)
            .background(Color.yellow.opacity(0.18), in: Capsule())
            .accessibilityLabel("Sample data, not a real measurement")
    }
}

/// Picker list used on both platforms to correct a length's stroke.
struct StrokePickerList: View {
    let length: Length
    let onSelect: (StrokeStyle) -> Void

    var body: some View {
        List {
            Section {
                ForEach(StrokeStyle.userSelectable) { style in
                    Button {
                        onSelect(style)
                    } label: {
                        HStack {
                            Circle().fill(style.tint).frame(width: 10, height: 10)
                            Text(style.displayName)
                            Spacer()
                            if style == length.stroke {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                }
            } header: {
                Text("Length \(length.index)")
            } footer: {
                Text(length.isUserOverride
                     ? "You set this stroke. Distance and time still come from Health."
                     : "Detected by Apple Watch. Your choice replaces it in SwimmingBeast.")
            }
        }
    }
}
