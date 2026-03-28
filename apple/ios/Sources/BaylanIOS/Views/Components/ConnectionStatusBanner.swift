import SwiftUI
import BaylanCore

/// Persistent status pill shown in the Mesh tab nav bar.
/// Searching state uses an animated pulse ring; connected shows a static dot.
struct MeshStatusPill: View {
    let peerCount: Int

    private var isSearching: Bool { peerCount == 0 }

    var body: some View {
        HStack(spacing: 5) {
            if isSearching {
                PulseRadarCompact()
                    .frame(width: 10, height: 10)
                    .clipped()
            } else {
                ConnectionDot(state: .connected, size: 6)
            }

            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSearching ? BaylanTheme.textSecondary : BaylanTheme.textPrimary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(BaylanTheme.surface)
        .clipShape(Capsule(style: .continuous))
        .animation(.spring(response: 0.4), value: peerCount)
    }

    private var statusText: String {
        switch peerCount {
        case 0: return "Searching..."
        case 1: return "1 in mesh"
        default: return "\(peerCount) in mesh"
        }
    }
}

/// Legacy name kept for any remaining call sites during migration
typealias ConnectionStatusBanner = MeshStatusPill
