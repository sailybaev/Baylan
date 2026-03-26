import SwiftUI
import BaylanCore

struct RootTabView: View {
    @Environment(\.appEnvironment) private var env

    var body: some View {
        #if targetEnvironment(macCatalyst)
        macBody
        #else
        iosBody
        #endif
    }

    // MARK: - iOS: tab bar at bottom

    private var iosBody: some View {
        tabView
            .safeAreaInset(edge: .top, spacing: 0) {
                if let env {
                    ConnectionStatusBanner(connectedCount: env.peerService.connectedPeerCount)
                        .padding(.top, 4)
                }
            }
    }

    // MARK: - Mac Catalyst: sidebar on the left, status in toolbar

    private var macBody: some View {
        tabView
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    macStatusIndicator
                }
            }
    }

    private var macStatusIndicator: some View {
        HStack(spacing: 6) {
            let count = env?.peerService.connectedPeerCount ?? 0
            Circle()
                .fill(count > 0 ? Color.green : BaylanTheme.textTertiary)
                .frame(width: 7, height: 7)
                .shadow(color: count > 0 ? Color.green.opacity(0.6) : .clear, radius: 4)
            Text(count == 0 ? "No nearby devices" : "\(count) nearby")
                .font(.caption)
                .foregroundStyle(BaylanTheme.textSecondary)
        }
        .animation(.spring(response: 0.3), value: env?.peerService.connectedPeerCount)
    }

    // MARK: - Shared tab structure

    private var tabView: some View {
        TabView {
            Tab("Chats", systemImage: "message.fill") {
                ConversationsView()
            }
            Tab("Nearby", systemImage: "antenna.radiowaves.left.and.right") {
                DiscoveryView()
            }
            Tab("Identity", systemImage: "person.crop.circle.fill") {
                IdentityView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(BaylanTheme.accent)
        .background(BaylanTheme.background)
    }
}
