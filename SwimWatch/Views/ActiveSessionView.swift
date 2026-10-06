import SwiftUI
import SwimCore
import SwimHealth
import WatchKit

/// Live swim: swipe left for controls, right for the lengths list. Opens on metrics.
struct ActiveSessionView: View {
    let session: any SwimSessionServing

    private enum Page: Hashable { case controls, metrics, lengths }
    @State private var page: Page = .metrics

    var body: some View {
        TabView(selection: $page) {
            ControlsPage(session: session).tag(Page.controls)
            MetricsPage(session: session).tag(Page.metrics)
            LengthsPage(session: session).tag(Page.lengths)
        }
        .tabViewStyle(.page)
    }
}

// MARK: - Metrics

struct MetricsPage: View {
    let session: any SwimSessionServing

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(SwimFormat.duration(session.elapsedTime(at: context.date)))
                        .font(.system(.title2, design: .rounded).monospacedDigit().weight(.semibold))
                        .foregroundStyle(session.state == .paused ? Color.secondary : Color.yellow)
                    Spacer()
                    if session.state == .paused {
                        Text("PAUSED").font(.caption2.weight(.bold)).foregroundStyle(.orange)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(session.lengths.count)")
                        .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                    Text(session.lengths.count == 1 ? "length" : "lengths")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text(SwimFormat.distance(session.distance, unit: session.displayUnit))
                    .font(.system(.body, design: .rounded).monospacedDigit())

                if let last = session.lastLength {
                    HStack(spacing: 6) {
                        Text("Last \(SwimFormat.split(last.duration))s")
                            .font(.footnote.monospacedDigit())
                        StrokeChip(stroke: last.stroke, source: last.strokeSource, compact: true)
                    }
                    Text(SwimFormat.pace(last.splitPace, unit: session.displayUnit))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("Push off — your first length appears at the wall.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "heart.fill").foregroundStyle(.red)
                    Text(session.heartRate.map { "\(Int($0.rounded()))" } ?? "--")
                        .font(.footnote.monospacedDigit())
                    Text("BPM").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    if session.isSimulated { SampleDataBadge() }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Lengths

struct LengthsPage: View {
    let session: any SwimSessionServing
    @State private var editing: Length?

    var body: some View {
        NavigationStack {
            Group {
                if session.lengths.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "list.number").font(.title3).foregroundStyle(.secondary)
                        Text("Lengths appear here after each wall.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List(session.lengths.reversed()) { length in
                        Button {
                            editing = length
                        } label: {
                            LengthRow(length: length)
                        }
                    }
                }
            }
            .navigationTitle("Lengths")
            .sheet(item: $editing) { length in
                StrokePickerList(length: length) { style in
                    session.overrideStroke(lengthId: length.id, style: style)
                    editing = nil
                }
            }
        }
    }
}

private struct LengthRow: View {
    let length: Length

    var body: some View {
        HStack {
            Text("\(length.index)")
                .font(.headline.monospacedDigit())
                .frame(minWidth: 24, alignment: .leading)
            StrokeChip(stroke: length.stroke, source: length.strokeSource, compact: true)
            Spacer()
            Text(SwimFormat.split(length.duration))
                .font(.body.monospacedDigit())
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to change the stroke")
    }
}

// MARK: - Controls

struct ControlsPage: View {
    let session: any SwimSessionServing
    @State private var confirmingEnd = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ControlButton(title: "End", systemImage: "xmark", tint: .red) {
                    confirmingEnd = true
                }
                if session.state == .paused {
                    ControlButton(title: "Resume", systemImage: "play.fill", tint: .yellow) { session.resume() }
                } else {
                    ControlButton(title: "Pause", systemImage: "pause.fill", tint: .yellow) { session.pause() }
                }
            }
            ControlButton(title: "Lock", systemImage: "drop.fill", tint: .cyan) {
                WKInterfaceDevice.current().enableWaterLock()
            }
            .disabled(session.isSimulated)
        }
        .confirmationDialog("End this swim?", isPresented: $confirmingEnd) {
            Button("End & Save", role: .destructive, action: end)
            Button("Keep Swimming", role: .cancel) {}
        }
    }

    private func end() {
        Task {
            if let workout = try? await session.endAndSave() {
                SwimConnectivity.shared.send(workout: workout)
            }
        }
    }
}

private struct ControlButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .tint(tint)
            Text(title).font(.caption2)
        }
    }
}

#Preview("Active – sample data") {
    ActiveSessionView(
        session: PreviewSwimSession(state: .running, lengths: SampleData.lengths(count: 7), autoGenerate: false)
    )
}
