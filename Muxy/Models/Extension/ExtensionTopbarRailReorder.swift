import CoreGraphics
import Foundation

enum ExtensionTopbarRailReorder {
    static func reorderedIDs(
        liveIDs: [String],
        frames: [String: CGRect],
        draggedID: String,
        locationY: CGFloat
    ) -> [String]? {
        guard liveIDs.contains(draggedID) else { return nil }

        let insertionIndex = liveIDs.reduce(into: 0) { count, id in
            guard id != draggedID, let frame = frames[id], frame.midY < locationY else { return }
            count += 1
        }

        var nextIDs = liveIDs
        nextIDs.removeAll { $0 == draggedID }
        nextIDs.insert(draggedID, at: insertionIndex)
        guard nextIDs != liveIDs else { return nil }
        return nextIDs
    }
}
