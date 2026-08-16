import SwiftUI

struct ExtensionTopbarRail: View {
    @Environment(ExtensionStore.self) private var extensionStore
    @State private var orderStore = ExtensionTopbarRailOrderStore.shared
    @State private var draggedID: String?
    @State private var liveOrderIDs: [String]?
    @State private var frames: [String: CGRect] = [:]

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
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: StringFramePreferenceKey<ExtensionIconRailFrameTag>.self,
                                value: [binding.id: geo.frame(in: .named("extension-icon-rail"))]
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, UIMetrics.spacing2)
            .contentShape(Rectangle())
            .highPriorityGesture(railDragGesture)
            .onPreferenceChange(StringFramePreferenceKey<ExtensionIconRailFrameTag>.self) { nextFrames in
                frames = nextFrames
            }
        }
        .coordinateSpace(name: "extension-icon-rail")
        .scrollDisabled(draggedID != nil)
        .onAppear(perform: persistFirstSeenIDs)
        .onChange(of: extensionStore.topbarItems) { _, items in
            persistFirstSeenIDs()
            guard let draggedID, !items.contains(where: { $0.id == draggedID }) else { return }
            persistLiveOrder()
            cancelDrag()
        }
    }

    private var railDragGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("extension-icon-rail"))
            .onChanged(handleDragChanged)
            .onEnded { _ in
                persistLiveOrder()
                withAnimation(.easeInOut(duration: 0.15)) {
                    cancelDrag()
                }
            }
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        let currentDraggedID: String
        let currentLiveIDs: [String]
        if let draggedID, let liveOrderIDs {
            currentDraggedID = draggedID
            currentLiveIDs = liveOrderIDs
        } else {
            guard let hitID = itemID(at: value.startLocation) else { return }
            let snapshot = displayedItems.map(\.id)
            draggedID = hitID
            liveOrderIDs = snapshot
            currentDraggedID = hitID
            currentLiveIDs = snapshot
        }

        guard let nextIDs = ExtensionTopbarRailReorder.reorderedIDs(
            liveIDs: currentLiveIDs,
            frames: frames,
            draggedID: currentDraggedID,
            locationY: value.location.y
        )
        else { return }

        withAnimation(.easeInOut(duration: 0.15)) {
            liveOrderIDs = nextIDs
        }
    }

    private func itemID(at point: CGPoint) -> String? {
        displayedItems.map(\.id).first { id in
            frames[id]?.contains(point) == true
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

    private func cancelDrag() {
        draggedID = nil
        liveOrderIDs = nil
    }
}
