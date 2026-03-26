import SwiftUI

// MARK: - Glass background modifier

public struct GlassBackground: ViewModifier {
    public var cornerRadius: CGFloat
    public var strokeOpacity: Double

    public init(
        cornerRadius: CGFloat = BaylanSpacing.cornerRadius,
        strokeOpacity: Double = 0.4
    ) {
        self.cornerRadius = cornerRadius
        self.strokeOpacity = strokeOpacity
    }

    public func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                BaylanTheme.surfaceElevated.opacity(strokeOpacity),
                                lineWidth: 0.5
                            )
                    }
                    .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 4)
            }
    }
}

// MARK: - Convenience extension

public extension View {
    func glass(cornerRadius: CGFloat = BaylanSpacing.cornerRadius, strokeOpacity: Double = 0.4) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }
}
