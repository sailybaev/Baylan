import SwiftUI
import BaylanCore

@main
struct BaylanApp: App {
    @State private var appEnvironment: AppEnvironment? = try? AppEnvironment.create()
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
                } else {
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
                }
            }
            .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1100, height: 720)
    }
}
