import SwiftUI
import BaylanCore

struct SettingsView: View {
    @Environment(\.appEnvironment) private var appEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var relayDurationHours: Double = 1.0
    @State private var showClearConfirm = false

    var body: some View {
        ZStack {
            BaylanTheme.background.ignoresSafeArea()

            Form {
                Section {
                    HStack {
                        Text("Display Name")
                            .foregroundStyle(BaylanTheme.textPrimary)
                        Spacer()
                        TextField("Your name", text: $displayName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(BaylanTheme.textSecondary)
                            .tint(BaylanTheme.accent)
                    }
                } header: {
                    Text("Profile")
                        .foregroundStyle(BaylanTheme.textSecondary)
                }
                .listRowBackground(BaylanTheme.surface)

                Section {
                    VStack(alignment: .leading, spacing: BaylanSpacing.sm) {
                        HStack {
                            Text("Store & Forward")
                                .foregroundStyle(BaylanTheme.textPrimary)
                            Spacer()
                            Text("\(Int(relayDurationHours))h")
                                .foregroundStyle(BaylanTheme.accent)
                                .monospacedDigit()
                        }

                        Slider(value: $relayDurationHours, in: 1...24, step: 1)
                            .tint(BaylanTheme.accent)

                        Text("Messages will be relayed for up to \(Int(relayDurationHours)) hour(s) while offline.")
                            .font(BaylanTypography.caption)
                            .foregroundStyle(BaylanTheme.textTertiary)
                    }
                    .padding(.vertical, BaylanSpacing.xs)
                } header: {
                    Text("Mesh Relay")
                        .foregroundStyle(BaylanTheme.textSecondary)
                }
                .listRowBackground(BaylanTheme.surface)

                Section {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Message History")
                        }
                        .foregroundStyle(BaylanTheme.destructive)
                    }
                } header: {
                    Text("Data")
                        .foregroundStyle(BaylanTheme.textSecondary)
                }
                .listRowBackground(BaylanTheme.surface)

                Section {
                    HStack {
                        Text("Version")
                            .foregroundStyle(BaylanTheme.textPrimary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(BaylanTheme.textTertiary)
                    }
                } header: {
                    Text("About")
                        .foregroundStyle(BaylanTheme.textSecondary)
                }
                .listRowBackground(BaylanTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .tint(BaylanTheme.accent)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveSettings() }
                    .foregroundStyle(BaylanTheme.accent)
            }
        }
        .onAppear { loadCurrentSettings() }
        .confirmationDialog(
            "Clear all message history?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) { clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func loadCurrentSettings() {
        displayName = appEnvironment?.identityService.localIdentity.displayName ?? ""
    }

    private func saveSettings() {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        appEnvironment?.identityService.updateDisplayName(displayName)
        dismiss()
    }

    private func clearHistory() {
        Task {
            // Clear all threads except nearby
            let threads = appEnvironment?.threadService.threads ?? []
            for thread in threads where !thread.isNearbyChannel {
                await appEnvironment?.threadService.deleteThread(thread.threadId)
            }
        }
    }
}
