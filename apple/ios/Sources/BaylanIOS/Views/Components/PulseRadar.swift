import SwiftUI
import BaylanCore

/// Animated radar for the discovery empty state.
/// Rings expand outward from center; peer dots appear on the ring as peers are found.
struct PulseRadar: View {
    let peerCount: Int
    var size: CGFloat = 200

    @State private var animate = false
    // Stable random angles for peer dots — seeded so they don't jump on re-render
    @State private var peerAngles: [Double] = []

    var body: some View {
        ZStack {
            // Expanding rings (3 rings, staggered)
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .strokeBorder(
                        BaylanTheme.accent.opacity(animate ? 0 : (0.35 - Double(i) * 0.08)),
                        lineWidth: 1
                    )
                    .frame(
                        width: animate ? size * (0.8 + Double(i) * 0.15) : size * 0.1,
                        height: animate ? size * (0.8 + Double(i) * 0.15) : size * 0.1
                    )
                    .animation(
                        .easeOut(duration: 2.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.6),
                        value: animate
                    )
            }

            // Center node (you)
            Circle()
                .fill(BaylanTheme.accent)
                .frame(width: 8, height: 8)
                .shadow(color: BaylanTheme.accent.opacity(0.6), radius: 6)

            // Peer dots on the outermost ring
            ForEach(0..<min(peerAngles.count, peerCount), id: \.self) { i in
                let angle = peerAngles[i]
                let radius = size * 0.38
                Circle()
                    .fill(BaylanTheme.accent)
                    .frame(width: 5, height: 5)
                    .shadow(color: BaylanTheme.accent.opacity(0.8), radius: 4)
                    .offset(
                        x: radius * cos(angle * .pi / 180),
                        y: radius * sin(angle * .pi / 180)
                    )
                    .transition(.scale(scale: 0, anchor: .center).combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            animate = true
            generateAngles(for: peerCount)
        }
        .onChange(of: peerCount) { _, newCount in
            generateAngles(for: newCount)
        }
    }

    private func generateAngles(for count: Int) {
        guard count > peerAngles.count else { return }
        // Append new angles without shuffling existing ones (dots don't jump)
        let needed = count - peerAngles.count
        let step = 360.0 / max(Double(count), 1)
        for i in 0..<needed {
            let base = step * Double(peerAngles.count + i)
            let jitter = Double.random(in: -15...15)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                peerAngles.append(base + jitter)
            }
        }
    }
}

/// Compact version for the status pill — just the pulsing dot with a ring
struct PulseRadarCompact: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(BaylanTheme.accent.opacity(animate ? 0 : 0.5), lineWidth: 1)
                .scaleEffect(animate ? 1.8 : 0.6)
                .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: animate)

            Circle()
                .fill(BaylanTheme.accent.opacity(0.5))
                .frame(width: 6, height: 6)
        }
        .onAppear { animate = true }
    }
}
