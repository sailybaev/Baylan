import SwiftUI
import BaylanCore

struct DeliveryStateIndicator: View {
    let state: DeliveryState

    @State private var dotPhase = 0

    var body: some View {
        Group {
            switch state {
            case .sending:
                sendingDots
            case .relayed:
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.system(size: 10))
                    .foregroundStyle(BaylanTheme.textSecondary)
                    .symbolEffect(.pulse)
            case .delivered:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(BaylanTheme.accent)
                    .transition(.scale.combined(with: .opacity))
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(BaylanTheme.destructive)
            }
        }
    }

    private var sendingDots: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { idx in
                Circle()
                    .fill(BaylanTheme.textTertiary)
                    .frame(width: 4, height: 4)
                    .opacity(dotPhase == idx ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.4).repeatForever().delay(Double(idx) * 0.15),
                        value: dotPhase
                    )
            }
        }
        .onAppear { dotPhase = 0 }
    }
}
