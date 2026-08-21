import Foundation
import Testing

@testable import Muxy

@Suite("ExtensionTopbarRailOrder")
struct ExtensionTopbarRailOrderTests {
    private struct Item: Identifiable, Equatable {
        let id: String
    }

    @Test("uses default visible order when saved is empty")
    func defaultOrderWhenSavedIsEmpty() {
        let visible = [Item(id: "A"), Item(id: "B"), Item(id: "C")]

        #expect(ExtensionTopbarRailOrder.displayed(visible: visible, savedIDs: []) == visible)
    }

    @Test("appends first-seen visible IDs without pruning hidden IDs")
    func appendsNewIDsWithoutPruning() {
        #expect(
            ExtensionTopbarRailOrder.appendingNewIDs(
                visibleIDs: ["A", "B"],
                savedIDs: []
            ) == ["A", "B"]
        )
        #expect(
            ExtensionTopbarRailOrder.appendingNewIDs(
                visibleIDs: ["C", "A"],
                savedIDs: ["A", "B"]
            ) == ["A", "B", "C"]
        )
        #expect(
            ExtensionTopbarRailOrder.appendingNewIDs(
                visibleIDs: ["A"],
                savedIDs: ["A", "B", "C"]
            ) == ["A", "B", "C"]
        )
    }

    @Test("restores a hidden ID into its saved slot")
    func hideThenRestoreSlot() {
        let saved = ["A", "B", "C", "D"]
        let hiddenC = [Item(id: "A"), Item(id: "B"), Item(id: "D")]

        #expect(
            ExtensionTopbarRailOrder.displayed(visible: hiddenC, savedIDs: saved).map(\.id)
                == ["A", "B", "D"]
        )
        #expect(
            ExtensionTopbarRailOrder.displayed(
                visible: [Item(id: "A"), Item(id: "B"), Item(id: "C"), Item(id: "D")],
                savedIDs: saved
            ).map(\.id) == ["A", "B", "C", "D"]
        )
    }

    @Test("drag splice keeps hidden IDs in their slots")
    func dragSpliceKeepsHiddenID() {
        #expect(
            ExtensionTopbarRailOrder.applyingLiveOrder(["D", "B", "A"], to: ["A", "B", "C", "D"])
                == ["D", "B", "C", "A"]
        )
        #expect(
            ExtensionTopbarRailOrder.applyingLiveOrder(["B", "A"], to: ["A", "B", "C"])
                == ["B", "A", "C"]
        )
        #expect(ExtensionTopbarRailOrder.applyingLiveOrder([], to: ["A", "B", "C"]) == ["A", "B", "C"])
    }

    @Test("appends a new live ID that precedes a persisted live ID")
    func appendsNewLiveIDPrecedingPersistedLiveID() {
        #expect(
            ExtensionTopbarRailOrder.applyingLiveOrder(["C", "A"], to: ["A", "B"])
                == ["C", "B", "A"]
        )
    }

    @Test("ignores unknown saved IDs")
    func ignoresUnknownSavedIDs() {
        let visible = [Item(id: "A"), Item(id: "B")]

        #expect(
            ExtensionTopbarRailOrder.displayed(visible: visible, savedIDs: ["X", "B", "Y"]).map(\.id)
                == ["B", "A"]
        )
    }

    @Test("displayed does not invent items")
    func displayedDoesNotInventItems() {
        let visible = [Item(id: "A")]

        #expect(
            ExtensionTopbarRailOrder.displayed(visible: visible, savedIDs: ["X", "A", "Y"]).map(\.id)
                == ["A"]
        )
    }

    @Test("persisting drops visible non-rail IDs, keeps hidden rail IDs, and appends first-seen rail IDs")
    func persistingPrunesVisibleNonRailAndKeepsHiddenRail() {
        #expect(
            ExtensionTopbarRailOrder.persisting(
                visibleRailIDs: ["panelA"],
                visibleNonRailIDs: ["popover"],
                savedIDs: ["popover", "panelA", "hiddenPanel"]
            ) == ["panelA", "hiddenPanel"]
        )
        #expect(
            ExtensionTopbarRailOrder.persisting(
                visibleRailIDs: ["panelA", "panelB"],
                visibleNonRailIDs: ["popover"],
                savedIDs: ["popover", "panelA", "hiddenPanel"]
            ) == ["panelA", "hiddenPanel", "panelB"]
        )
    }

    @Test("persisting after a drag splice still keeps a hidden panel ID")
    func persistingAfterDragSpliceKeepsHiddenPanel() {
        #expect(
            ExtensionTopbarRailOrder.persisting(
                visibleRailIDs: ["panelA", "panelB"],
                visibleNonRailIDs: ["popover"],
                savedIDs: ExtensionTopbarRailOrder.applyingLiveOrder(
                    ["panelB", "panelA"],
                    to: ["popover", "panelA", "hiddenPanel"]
                )
            ) == ["panelB", "hiddenPanel", "panelA"]
        )
    }
}

@Suite("ExtensionTopbarPlacement")
struct ExtensionTopbarPlacementTests {
    @Test("mixed list partitions rail-eligible items")
    func mixedListPartitions() {
        let popover = binding(id: "popover", action: .openPopover(popover: "usage"))
        let panel = binding(id: "panel", action: .togglePanel(panel: "hello"))
        let event = binding(id: "event", action: .event)
        let items = [popover, panel, event]

        #expect(ExtensionTopbarPlacement.railItems(from: items).map(\.id) == [panel.id])
        #expect(
            ExtensionTopbarPlacement.titleBarItems(from: items, railEnabled: true).map(\.id)
                == [popover.id, event.id]
        )
        #expect(
            ExtensionTopbarPlacement.titleBarItems(from: items, railEnabled: false).map(\.id)
                == items.map(\.id)
        )
    }

    @Test("title bar keeps togglePanel items when the rail is off")
    func titleBarKeepsTogglePanelWhenRailOff() {
        let panel = binding(id: "panel", action: .togglePanel(panel: "hello"))
        #expect(
            ExtensionTopbarPlacement.titleBarItems(from: [panel], railEnabled: false).map(\.id)
                == [panel.id]
        )
    }

    private func binding(id: String, action: ExtensionCommandAction) -> ExtensionStore.TopbarItemBinding {
        let muxyExtension = MuxyExtension(
            id: "demo",
            directory: URL(fileURLWithPath: "/tmp/demo"),
            manifest: ExtensionManifest(
                name: "demo",
                version: "1.0.0",
                background: "background.js",
                commands: [ExtensionPaletteCommand(id: id, title: id, action: action)]
            )
        )
        return ExtensionStore.TopbarItemBinding(
            muxyExtension: muxyExtension,
            item: ExtensionTopbarItem(id: id, icon: .symbol("a"), tooltip: nil, command: id),
            liveIcon: nil,
            liveVisible: nil
        )
    }
}

@Suite("ExtensionTopbarRailReorder")
struct ExtensionTopbarRailReorderTests {
    private let frames: [String: CGRect] = [
        "A": CGRect(x: 0, y: 0, width: 32, height: 32),
        "B": CGRect(x: 0, y: 32, width: 32, height: 32),
        "C": CGRect(x: 0, y: 64, width: 32, height: 32),
        "D": CGRect(x: 0, y: 96, width: 32, height: 32),
    ]

    @Test("swaps with the adjacent item below")
    func adjacentSwapDown() {
        #expect(
            ExtensionTopbarRailReorder.reorderedIDs(
                liveIDs: ["A", "B", "C"],
                frames: frames,
                draggedID: "A",
                locationY: 49
            ) == ["B", "A", "C"]
        )
    }

    @Test("swaps with the adjacent item above")
    func adjacentSwapUp() {
        #expect(
            ExtensionTopbarRailReorder.reorderedIDs(
                liveIDs: ["A", "B", "C"],
                frames: frames,
                draggedID: "C",
                locationY: 47
            ) == ["A", "C", "B"]
        )
    }

    @Test("skips over a middle item")
    func skipOverMiddle() {
        #expect(
            ExtensionTopbarRailReorder.reorderedIDs(
                liveIDs: ["A", "B", "C"],
                frames: frames,
                draggedID: "A",
                locationY: 81
            ) == ["B", "C", "A"]
        )
    }

    @Test("moves to first and last")
    func moveToFirstAndLast() {
        #expect(
            ExtensionTopbarRailReorder.reorderedIDs(
                liveIDs: ["A", "B", "C"],
                frames: frames,
                draggedID: "C",
                locationY: 15
            ) == ["C", "A", "B"]
        )
        #expect(
            ExtensionTopbarRailReorder.reorderedIDs(
                liveIDs: ["A", "B", "C"],
                frames: frames,
                draggedID: "A",
                locationY: 113
            ) == ["B", "C", "A"]
        )
    }

    @Test("returns nil when the insertion index is unchanged")
    func sameIndexNoOp() {
        #expect(
            ExtensionTopbarRailReorder.reorderedIDs(
                liveIDs: ["A", "B", "C"],
                frames: frames,
                draggedID: "B",
                locationY: 48
            ) == nil
        )
    }

    @Test("ignores other IDs that have no frame")
    func missingFrameIgnored() {
        var partial = frames
        partial.removeValue(forKey: "B")
        #expect(
            ExtensionTopbarRailReorder.reorderedIDs(
                liveIDs: ["A", "B", "C"],
                frames: partial,
                draggedID: "A",
                locationY: 81
            ) == ["B", "A", "C"]
        )
    }

    @Test("returns nil for an unknown dragged ID")
    func unknownDraggedID() {
        #expect(
            ExtensionTopbarRailReorder.reorderedIDs(
                liveIDs: ["A", "B", "C"],
                frames: frames,
                draggedID: "Z",
                locationY: 48
            ) == nil
        )
    }
}

@Suite("ExtensionTopbarRailOrderStore", .serialized)
@MainActor
struct ExtensionTopbarRailOrderStoreTests {
    @Test("reads and writes the rail order array")
    func readsAndWritesOrder() throws {
        let suiteName = "muxy.tests.rail-order.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ExtensionTopbarRailOrderStore(defaults: defaults)
        #expect(store.ids == TopbarPreferences.defaultRailOrder)

        store.ids = ["ext:a", "ext:b"]
        #expect(defaults.stringArray(forKey: TopbarPreferences.railOrderKey) == ["ext:a", "ext:b"])
    }

    @Test("removes the last visible item after it stops being rail eligible")
    func reconcileRemovesLastVisibleNonRailItem() throws {
        let suiteName = "muxy.tests.rail-order-reconcile.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["ext:item"], forKey: TopbarPreferences.railOrderKey)
        let store = ExtensionTopbarRailOrderStore(defaults: defaults)

        store.reconcile(visibleRailIDs: [], visibleNonRailIDs: ["ext:item"])

        #expect(store.ids.isEmpty)
        #expect(defaults.stringArray(forKey: TopbarPreferences.railOrderKey)?.isEmpty == true)
    }

    @Test("reloads when UserDefaults change")
    func reloadsOnDefaultsChange() async throws {
        let suiteName = "muxy.tests.rail-order-reload.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ExtensionTopbarRailOrderStore(defaults: defaults)
        defaults.set(["ext:z"], forKey: TopbarPreferences.railOrderKey)

        await waitFor { store.ids == ["ext:z"] }
        #expect(store.ids == ["ext:z"])
    }

    private func waitFor(
        timeoutNanoseconds: UInt64 = 200_000_000,
        condition: @MainActor () -> Bool
    ) async {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while !condition(), DispatchTime.now().uptimeNanoseconds < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
