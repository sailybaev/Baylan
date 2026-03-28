import SwiftUI
import BaylanCore

/// Unified connection state dot. Four states, one component, used everywhere.
enum ConnectionState: Equatable {
    case searching
    case connected
    case weak
    case disconnected
}

struct ConnectionDot: View {
    let state: ConnectionState
    var size: CGFloat = 6

    @State private var pulse = false
    @State private var flicker = false

    var body: some View {
        ZStack {
            // Glow for connected state only
            if state == .connected {
                Circle()
                    .fill(BaylanTheme.accent.opacity(0.35))
                    .frame(width: size * 2.5, height: size * 2.5)
                    .blur(radius: 3)
            }

            Circle()
                .fill(dotColor)
                .frame(width: size, height: size)
                .opacity(opacity)
                .scaleEffect(scale)
        }
        .onAppear { startAnimations() }
        .onChange(of: state) { _, _ in startAnimations() }
        .animation(.spring(response: 0.3), value: state)
    }

    private var dotColor: Color {
        switch state {
        case .searching:    return BaylanTheme.textTertiary
        case .connected:    return BaylanTheme.accent
        case .weak:         return BaylanTheme.warning
        case .disconnected: return BaylanTheme.textTertiary
        }
    }

    private var opacity: Double {
        switch state {
        case .searching:    return pulse ? 0.35 : 1.0
        case .weak:         return flicker ? 0.55 : 1.0
        default:            return 1.0
        }
    }

    private var scale: CGFloat {
        switch state {
        case .searching: return pulse ? 0.7 : 1.0
        default:         return 1.0
        }
    }

    private func startAnimations() {
        switch state {
        case .searching:
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
            flicker = false
        case .weak:
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                flicker.toggle()
            }
            pulse = false
        default:
            pulse = false
            flicker = false
        }
    }
}
