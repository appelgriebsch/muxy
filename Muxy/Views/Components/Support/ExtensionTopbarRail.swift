import SwiftUI

struct ExtensionTopbarRail: View {
    @Environment(ExtensionStore.self) private var extensionStore
    @State private var orderStore = ExtensionTopbarRailOrderStore.shared
    @State private var draggedID: String?
    @State private var liveOrderIDs: [String]?
    @State private var frames: [String: CGRect] = [:]
    @State private var lastReorderTargetID: String?

    private var displayedItems: [ExtensionStore.TopbarItemBinding] {
        ExtensionTopbarRailOrder.displayed(
            visible: extensionStore.topbarItems,
            savedIDs: liveOrderIDs ?? orderStore.ids
        )
    }

    var body: some View {
        let items = displayedItems
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(items) { binding in
                    ExtensionTopbarItemControl(
                        binding: binding,
                        preferredEdge: .minX,
                        isCommandEnabled: draggedID == nil,
                        showsSelectionChrome: true
                    )
                    .fixedSize()
                    .background {
                        if draggedID != nil {
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: StringFramePreferenceKey<ExtensionIconRailFrameTag>.self,
                                    value: [binding.id: geo.frame(in: .named("extension-icon-rail"))]
                                )
                            }
                        }
                    }
                    .gesture(itemDragGesture(for: binding.id))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, UIMetrics.spacing2)
            .onPreferenceChange(StringFramePreferenceKey<ExtensionIconRailFrameTag>.self) { nextFrames in
                guard draggedID != nil else { return }
                frames = nextFrames
            }
        }
        .coordinateSpace(name: "extension-icon-rail")
        .onAppear(perform: persistFirstSeenIDs)
        .onChange(of: extensionStore.topbarItems) { _, items in
            persistFirstSeenIDs()
            guard let draggedID, !items.contains(where: { $0.id == draggedID }) else { return }
            persistLiveOrder()
            cancelDrag()
        }
    }

    private func persistFirstSeenIDs() {
        orderStore.ids = ExtensionTopbarRailOrder.appendingNewIDs(
            visibleIDs: extensionStore.topbarItems.map(\.id),
            savedIDs: orderStore.ids
        )
    }

    private func persistLiveOrder() {
        guard liveOrderIDs != nil else { return }
        let liveIDs = displayedItems.map(\.id)
        orderStore.ids = ExtensionTopbarRailOrder.applyingLiveOrder(liveIDs, to: orderStore.ids)
    }

    private func itemDragGesture(for id: String) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("extension-icon-rail"))
            .onChanged { value in
                if draggedID == nil {
                    draggedID = id
                    lastReorderTargetID = nil
                    liveOrderIDs = displayedItems.map(\.id)
                }
                reorderIfNeeded(at: value.location)
            }
            .onEnded { _ in
                persistLiveOrder()
                withAnimation(.easeInOut(duration: 0.15)) {
                    cancelDrag()
                }
            }
    }

    private func reorderIfNeeded(at location: CGPoint) {
        guard let draggedID else { return }
        let displayedIDs = displayedItems.map(\.id)
        var hoveredTargetID: String?

        for (id, frame) in frames where id != draggedID {
            guard frame.contains(location) else { continue }
            hoveredTargetID = id
            guard lastReorderTargetID != id else { return }
            guard let sourceIndex = displayedIDs.firstIndex(of: draggedID),
                  let destIndex = displayedIDs.firstIndex(of: id)
            else { return }

            lastReorderTargetID = id
            var nextLiveIDs = displayedIDs
            nextLiveIDs.remove(at: sourceIndex)
            nextLiveIDs.insert(draggedID, at: destIndex)
            withAnimation(.easeInOut(duration: 0.15)) {
                liveOrderIDs = nextLiveIDs
            }
            return
        }

        if hoveredTargetID == nil {
            lastReorderTargetID = nil
        }
    }

    private func cancelDrag() {
        draggedID = nil
        liveOrderIDs = nil
        frames = [:]
        lastReorderTargetID = nil
    }
}
