import SwiftUI
import BaylanCore

struct AvatarView: View {
    let name: String
    let userId: String
    var size: CGFloat = BaylanSpacing.avatarMedium
    var showAccentRing: Bool = false

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var gradientColors: [Color] {
        // Deterministic colors seeded from userId
        let hash = userId.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let hue = Double(hash % 360) / 360.0
        return [
            Color(hue: hue, saturation: 0.6, brightness: 0.4),
            Color(hue: (hue + 0.1).truncatingRemainder(dividingBy: 1.0), saturation: 0.7, brightness: 0.3)
        ]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay {
            if showAccentRing {
                Circle()
                    .strokeBorder(BaylanTheme.accent, lineWidth: 2)
            }
        }
    }
}
