import SwiftUI
import BaylanCore

struct IdentityView: View {
    @Environment(\.appEnvironment) private var appEnvironment

    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var showScanner = false
    @State private var showCopiedFeedback = false

    private var identity: Identity? {
        appEnvironment?.identityService.localIdentity
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BaylanTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: BaylanSpacing.xxl) {
                        qrSection
                        identityInfoSection
                        actionsSection
                    }
                    .padding(.horizontal, BaylanSpacing.lg)
                    .padding(.top, BaylanSpacing.xl)
                }
            }
            .navigationTitle("Identity")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
        }
        .sheet(isPresented: $showScanner) {
            scannerSheet
        }
        .alert("Display Name", isPresented: $isEditingName) {
            TextField("Name", text: $editedName)
            Button("Save") { saveName() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This name is visible to nearby peers.")
        }
    }

    private var qrSection: some View {
        Group {
            if let identity = identity,
               let qrData = appEnvironment?.identityService.identityPayloadForQR() {
                VStack(spacing: BaylanSpacing.lg) {
                    QRCodeGenerator(data: qrData, size: 220)
                        .shadow(color: BaylanTheme.accent.opacity(0.3), radius: 20)

                    Text("Share this QR to verify your identity")
                        .font(BaylanTypography.caption)
                        .foregroundStyle(BaylanTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(BaylanSpacing.xl)
                .glass()
            }
        }
    }

    private var identityInfoSection: some View {
        VStack(spacing: BaylanSpacing.md) {
            if let identity = identity {
                InfoRow(label: "Display Name", value: identity.displayName)
                InfoRow(label: "User ID", value: identity.displayId, mono: true) {
                    copyToClipboard(identity.userId)
                }
                InfoRow(label: "Verified", value: identity.verified ? "Yes" : "No")
            }
        }
        .padding(BaylanSpacing.md)
        .glass()
    }

    private var actionsSection: some View {
        VStack(spacing: BaylanSpacing.sm) {
            Button {
                showScanner = true
            } label: {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    .font(BaylanTypography.headline)
                    .foregroundStyle(BaylanTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BaylanSpacing.md)
                    .glass()
            }

            NavigationLink {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(BaylanTypography.headline)
                    .foregroundStyle(BaylanTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BaylanSpacing.md)
                    .glass()
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                startEditingName()
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(BaylanTheme.accent)
            }
        }
    }

    private var scannerSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                QRScannerView { data in
                    handleScannedQR(data)
                    showScanner = false
                }
            }
            .navigationTitle("Scan QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showScanner = false }
                        .foregroundStyle(BaylanTheme.accent)
                }
            }
        }
    }

    private func startEditingName() {
        editedName = identity?.displayName ?? ""
        isEditingName = true
    }

    private func saveName() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appEnvironment?.identityService.updateDisplayName(trimmed)
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        #if !targetEnvironment(macCatalyst)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        withAnimation { showCopiedFeedback = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showCopiedFeedback = false }
        }
    }

    private func handleScannedQR(_ data: Data) {
        // Parse JSON identity payload and save as verified contact
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String,
              let name = json["name"] as? String,
              let pkBase64 = json["pk"] as? String,
              let publicKey = Data(base64Encoded: pkBase64) else { return }

        let scannedIdentity = Identity(
            userId: id,
            displayName: name,
            publicKey: publicKey,
            isSelf: false,
            firstSeen: Date(),
            lastSeen: Date(),
            verified: true
        )

        Task {
            try? await appEnvironment?.repository.saveIdentity(scannedIdentity)
        }
        #if !targetEnvironment(macCatalyst)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var mono: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(label)
                .font(BaylanTypography.subheadline)
                .foregroundStyle(BaylanTheme.textSecondary)

            Spacer()

            Text(value)
                .font(mono ? BaylanTypography.mono : BaylanTypography.subheadline)
                .foregroundStyle(BaylanTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            if let action = action {
                Button(action: action) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundStyle(BaylanTheme.accent)
                }
            }
        }
        .padding(.vertical, BaylanSpacing.xs)
    }
}
