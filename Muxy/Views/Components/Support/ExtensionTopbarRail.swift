import SwiftUI

struct ExtensionTopbarRail: View {
    @Environment(ExtensionStore.self) private var extensionStore
    @State private var orderStore = ExtensionTopbarRailOrderStore.shared
    @State private var draggedID: String?
    @State private var liveOrderIDs: [String]?
    @State private var frames: [String: CGRect] = [:]
    @GestureState private var isDragging = false

    private var railItems: [ExtensionStore.TopbarItemBinding] {
        ExtensionTopbarPlacement.railItems(from: extensionStore.topbarItems)
    }

    private var visibleNonRailIDs: [String] {
        extensionStore.topbarItems.filter { !$0.isRailEligible }.map(\.id)
    }

    private var displayedItems: [ExtensionStore.TopbarItemBinding] {
        ExtensionTopbarRailOrder.displayed(
            visible: railItems,
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
        .onDisappear(perform: finishDrag)
        .onChange(of: isDragging) { _, dragging in
            guard !dragging else { return }
            finishDrag()
        }
        .onChange(of: extensionStore.topbarItems) {
            guard let draggedID, !railItems.contains(where: { $0.id == draggedID }) else { return }
            finishDrag()
        }
    }

    private var railDragGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("extension-icon-rail"))
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged(handleDragChanged)
            .onEnded { _ in
                finishDrag()
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

    private func persistLiveOrder() {
        guard liveOrderIDs != nil else { return }
        let liveIDs = displayedItems.map(\.id)
        orderStore.ids = ExtensionTopbarRailOrder.persisting(
            visibleRailIDs: railItems.map(\.id),
            visibleNonRailIDs: visibleNonRailIDs,
            savedIDs: ExtensionTopbarRailOrder.applyingLiveOrder(liveIDs, to: orderStore.ids)
        )
    }

    private func finishDrag() {
        persistLiveOrder()
        withAnimation(.easeInOut(duration: 0.15)) {
            cancelDrag()
        }
    }

    private func cancelDrag() {
        draggedID = nil
        liveOrderIDs = nil
    }
}
