import SwiftUI
import BaylanCore

struct PeerRow: View {
    let peer: Peer

    var body: some View {
        HStack(spacing: BaylanSpacing.md) {
            AvatarView(
                name: peer.identity.displayName,
                userId: peer.identity.userId,
                showAccentRing: peer.isConnected
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: BaylanSpacing.xs) {
                    Text(peer.identity.displayName)
                        .font(BaylanTypography.headline)
                        .foregroundStyle(BaylanTheme.textPrimary)

                    if peer.identity.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(BaylanTheme.accent)
                    }
                }

                Text(peer.identity.displayId)
                    .font(BaylanTypography.caption)
                    .foregroundStyle(BaylanTheme.textTertiary)
                    .fontDesign(.monospaced)
            }

            Spacer(minLength: 0)

            signalBars
        }
        .padding(.horizontal, BaylanSpacing.md)
        .padding(.vertical, BaylanSpacing.sm)
        .background(BaylanTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BaylanSpacing.cornerRadiusSmall))
    }

    private var signalBars: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < signalLevel ? BaylanTheme.accent : BaylanTheme.surfaceElevated)
                    .frame(width: 4, height: CGFloat(6 + index * 4))
            }
        }
    }

    private var signalLevel: Int {
        guard let strength = peer.signalStrength else { return 2 }
        switch strength {
        case ..<(-80): return 1
        case (-80)..<(-65): return 2
        case (-65)..<(-50): return 3
        default: return 4
        }
    }
}
