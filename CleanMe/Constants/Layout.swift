import CoreGraphics

nonisolated enum Layout {
    static let contentPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 20
    static let rowSpacing: CGFloat = 12
    static let cornerRadius: CGFloat = 12
    /// Readable column width; wider windows center the content.
    static let contentMaxWidth: CGFloat = 960

    static let windowMinWidth: CGFloat = 920
    /// Tall enough for the whole sidebar to fit without scrolling.
    static let windowMinHeight: CGFloat = 800
    static let sidebarMinWidth: CGFloat = 220
    static let sidebarIdealWidth: CGFloat = 250

    static let iconSize: CGFloat = 32
    static let sidebarIconSize: CGFloat = 20
    static let storageBarHeight: CGFloat = 14
}
