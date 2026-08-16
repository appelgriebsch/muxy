import AppKit
import Testing

@testable import Muxy

@Suite("ExtensionPopoverLayout")
@MainActor
struct ExtensionPopoverLayoutTests {
    @Test("clamps rail popovers to remaining space on the chosen edge")
    func clampsToRemainingSpaceOnMinX() {
        let remaining = ExtensionPopoverLayout.remainingSpace(
            preferredEdge: .minX,
            windowSize: CGSize(width: 400, height: 300),
            railWidth: 44,
            margin: 16
        )

        #expect(remaining == CGSize(width: 324, height: 268))

        let size = ExtensionPopoverLayout.clampedContentSize(
            width: 600,
            height: 720,
            remainingOnEdge: remaining
        )
        #expect(size == NSSize(width: 324, height: 268))
    }

    @Test("does not add remaining-space clamp below the title bar")
    func skipsRemainingSpaceOnMaxY() {
        #expect(
            ExtensionPopoverLayout.remainingSpace(
                preferredEdge: .maxY,
                windowSize: CGSize(width: 400, height: 300)
            ) == nil
        )

        let size = ExtensionPopoverLayout.clampedContentSize(
            width: 320,
            height: 360,
            remainingOnEdge: nil
        )
        #expect(size == NSSize(width: 320, height: 360))
    }
}