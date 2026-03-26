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
    }

    // MARK: - Mac Catalyst: sidebar on the left, status in toolbar

    private var macBody: some View {
        tabView
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
