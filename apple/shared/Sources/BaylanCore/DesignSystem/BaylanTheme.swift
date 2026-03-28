import SwiftUI

public enum BaylanTheme {
    // MARK: - Backgrounds
    /// Deep black — primary app background
    public static let background = Color(hex: "0A0A0A")
    /// Charcoal — card / row surfaces
    public static let surface = Color(hex: "1A1A1A")
    /// Slightly elevated surface for nested elements
    public static let surfaceElevated = Color(hex: "2A2A2A")
    /// Divider / border color
    public static let separator = Color(hex: "2C2C2E")

    // MARK: - Accent
    /// Neon lime — ONLY for active states and connectivity indicators
    public static let accent = Color(hex: "B8FF00")
    public static let accentDim = accent.opacity(0.25)
    public static let accentGlow = accent.opacity(0.12)

    // MARK: - Text
    public static let textPrimary = Color.white
    public static let textSecondary = Color(hex: "8E8E93")
    public static let textTertiary = Color(hex: "48484A")

    // MARK: - Semantic
    public static let destructive = Color(hex: "FF453A")
    public static let warning = Color(hex: "FF9F0A")

    // MARK: - Message bubbles
    /// Sent message bubble — accent tint, not opaque green
    public static let bubbleSent = accent.opacity(0.13)
    /// Received message bubble
    public static let bubbleReceived = Color(hex: "1E1E1E")
    /// Nearby channel bubble — subtle blue tint
    public static let bubbleNearby = Color(hex: "141422")
}
