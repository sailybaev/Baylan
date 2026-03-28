import CoreFoundation

public enum BaylanSpacing {
    public static let xs:   CGFloat = 4
    public static let sm:   CGFloat = 8
    public static let md:   CGFloat = 12
    public static let lg:   CGFloat = 16
    public static let xl:   CGFloat = 20
    public static let xxl:  CGFloat = 24
    public static let xxxl: CGFloat = 32

    /// Standard card / row corner radius
    public static let cornerRadius:      CGFloat = 14
    /// Message bubbles
    public static let cornerRadiusBubble: CGFloat = 18
    /// Bubble tail corner (the corner closest to the sender)
    public static let cornerRadiusBubbleTail: CGFloat = 5
    /// Smaller elements (badges, chips)
    public static let cornerRadiusSmall: CGFloat = 10
    /// Pill-shaped (fully rounded)
    public static let cornerRadiusFull:  CGFloat = 9999

    /// Standard horizontal padding for screen content
    public static let screenHorizontal: CGFloat = 16
    /// Avatar sizes
    public static let avatarSmall:  CGFloat = 32
    public static let avatarMedium: CGFloat = 44
    public static let avatarLarge:  CGFloat = 80

    /// Tab bar + input bar safe area extra padding
    public static let bottomSafeExtra: CGFloat = 8
}
