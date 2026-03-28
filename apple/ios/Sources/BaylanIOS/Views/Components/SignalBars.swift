import SwiftUI
import BaylanCore

/// Four rising bars showing signal strength.
/// `strength` is a 0.0–1.0 normalized value from `Peer.signalStrength`.
/// Each bar animates independently when the value changes.
struct SignalBars: View {
    let strength: Double?

    private var level: Int {
        guard let s = strength else { return 0 }
        switch s {
        case ..<0.25: return 1
        case 0.25..<0.5: return 2
        case 0.5..<0.75: return 3
        default: return 4
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < level ? BaylanTheme.accent : BaylanTheme.textTertiary.opacity(0.35))
                    .frame(width: 3, height: CGFloat(8 + i * 4))
                    .animation(.spring(response: 0.4).delay(Double(i) * 0.04), value: level)
            }
        }
    }
}
