import SwiftUI
import BaylanCore

struct RootTabView: View {
    @Environment(\.appEnvironment) private var env
    @State private var macSelection: MacRoute? = .mesh

    var body: some View {
        #if targetEnvironment(macCatalyst)
        macBody
        #else
        iosBody
        #endif
    }

    // MARK: - iOS

    private var iosBody: some View {
        TabView {
            Tab("Mesh", systemImage: "antenna.radiowaves.left.and.right") {
                MeshFeedView()
            }
            Tab("People", systemImage: "person.2.fill") {
                PeopleView()
            }
            Tab("You", systemImage: "person.crop.circle.fill") {
                IdentityView()
            }
        }
        .tint(BaylanTheme.accent)
        .background(BaylanTheme.background)
    }

    // MARK: - Mac Catalyst

    // NavigationSplitView gives full control over sidebar labels.
    // SwiftUI's List selection automatically adapts label foreground to the
    // selection background luminance — lime (#B8FF00) → black text/icon. ✓

    private var macBody: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(selection: $macSelection) {
                NavigationLink(value: MacRoute.mesh) {
                    sidebarRow("Mesh", systemImage: "antenna.radiowaves.left.and.right", route: .mesh)
                }
                NavigationLink(value: MacRoute.people) {
                    sidebarRow("People", systemImage: "person.2.fill", route: .people)
                }
                NavigationLink(value: MacRoute.you) {
                    sidebarRow("You", systemImage: "person.crop.circle.fill", route: .you)
                }
            }
            // Scoped tint: lime for sidebar selection only.
            // NOT propagated to the detail column — search field focus ring stays system blue.
            .tint(BaylanTheme.accent)
            .listStyle(.sidebar)
            .navigationTitle("Bayla")
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } detail: {
            switch macSelection ?? .mesh {
            case .mesh:   MeshFeedView()
            case .people: PeopleView()
            case .you:    IdentityView()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func sidebarRow(_ title: String, systemImage: String, route: MacRoute) -> some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(macSelection == route ? Color.black : Color.primary)
    }
}

// MARK: - Mac navigation destinations

private enum MacRoute: Hashable {
    case mesh, people, you
}
