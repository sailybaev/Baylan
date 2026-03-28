import SwiftUI
import BaylanCore

@main
struct BaylanApp: App {
    @State private var appEnvironment: AppEnvironment?
    @State private var loadFailed = false
    @State private var appStarted = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let env = appEnvironment {
                    RootTabView()
                        .environment(\.appEnvironment, env)
                        .task {
                            guard !appStarted else { return }
                            appStarted = true
                            await env.start()
                        }
                } else if loadFailed {
                    VStack(spacing: BaylanSpacing.lg) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(BaylanTheme.destructive)
                        Text("Failed to initialize identity.")
                            .foregroundStyle(BaylanTheme.textSecondary)
                            .font(BaylanTypography.body)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BaylanTheme.background)
                } else {
                    splashScreen
                }
            }
            .task { await initializeApp() }
            .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1100, height: 720)
    }

    private var splashScreen: some View {
        ZStack {
            BaylanTheme.background.ignoresSafeArea()
            VStack(spacing: BaylanSpacing.xl) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 52, weight: .ultraLight))
                    .foregroundStyle(BaylanTheme.accent)
                ProgressView()
                    .tint(BaylanTheme.accent)
            }
        }
    }

    private func initializeApp() async {
        do {
            appEnvironment = try await AppEnvironment.create()
        } catch {
            loadFailed = true
        }
    }
}
