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
