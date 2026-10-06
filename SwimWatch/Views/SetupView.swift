import SwiftUI
import SwimCore
import SwimHealth
import WatchKit

struct SetupView: View {
    let session: any SwimSessionServing

    @AppStorage(SwimSettingsKey.defaultPoolLength) private var poolRaw = PoolLength.meters25.rawValue
    @State private var isStarting = false
    @State private var errorMessage: String?

    private var pool: PoolLength { PoolLength(rawValue: poolRaw) ?? .meters25 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pool length")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ForEach(PoolLength.allCases) { option in
                        PoolOptionButton(pool: option, isSelected: option == pool) {
                            poolRaw = option.rawValue
                        }
                    }

                    Button(action: start) {
                        if isStarting {
                            ProgressView()
                        } else {
                            Label("Start Swim", systemImage: "figure.pool.swim")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(isStarting || session.state == .starting)
                    .padding(.top, 4)

                    if let message = errorMessage ?? failureMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if session.isSimulated {
                        SampleDataBadge()
                        Text("Simulator: lengths are generated every few seconds instead of detected.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("SwimmingBeast")
        }
    }

    private var failureMessage: String? {
        if case .failed(let message) = session.state { return message }
        return nil
    }

    private func start() {
        errorMessage = nil
        isStarting = true
        Task {
            defer { isStarting = false }
            do {
                try await session.requestAuthorization()
                try await session.start(poolLength: pool.measurement)
                if !session.isSimulated {
                    WKInterfaceDevice.current().enableWaterLock()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct PoolOptionButton: View {
    let pool: PoolLength
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(pool.displayName).font(.headline)
                    Text(pool.subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.blue : Color.secondary)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    SetupView(session: PreviewSwimSession(autoGenerate: false))
}
