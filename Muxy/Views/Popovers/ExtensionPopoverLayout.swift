import AppKit

@MainActor
enum ExtensionPopoverLayout {
    static func clampedContentSize(
        width: Double,
        height: Double,
        remainingOnEdge: CGSize?
    ) -> NSSize {
        var clampedWidth = min(max(width, PopoverHost.minSize), PopoverHost.maxWidth)
        var clampedHeight = min(max(height, PopoverHost.minSize), PopoverHost.maxHeight)
        if let remainingOnEdge {
            clampedWidth = min(clampedWidth, max(remainingOnEdge.width, PopoverHost.minSize))
            clampedHeight = min(clampedHeight, max(remainingOnEdge.height, PopoverHost.minSize))
        }
        return NSSize(width: clampedWidth, height: clampedHeight)
    }

    static func remainingSpace(
        preferredEdge: NSRectEdge,
        windowSize: CGSize,
        railWidth: CGFloat = UIMetrics.extensionIconRailWidth,
        margin: CGFloat = UIMetrics.spacing7
    ) -> CGSize? {
        guard preferredEdge == .minX else { return nil }
        return CGSize(
            width: max(windowSize.width - railWidth - margin * 2, 0),
            height: max(windowSize.height - margin * 2, 0)
        )
    }
}
