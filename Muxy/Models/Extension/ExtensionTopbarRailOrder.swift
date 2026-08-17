import Foundation

enum ExtensionTopbarRailOrder {
    static func displayed<Item: Identifiable>(
        visible: [Item],
        savedIDs: [String]
    ) -> [Item] where Item.ID == String {
        let byID = Dictionary(visible.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        var result: [Item] = []
        result.reserveCapacity(visible.count)

        for id in savedIDs {
            guard let item = byID[id], seen.insert(id).inserted else { continue }
            result.append(item)
        }

        for item in visible where seen.insert(item.id).inserted {
            result.append(item)
        }

        return result
    }

    static func appendingNewIDs(visibleIDs: [String], savedIDs: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(savedIDs.count + visibleIDs.count)

        for id in savedIDs where seen.insert(id).inserted {
            result.append(id)
        }
        for id in visibleIDs where seen.insert(id).inserted {
            result.append(id)
        }

        return result
    }

    static func applyingLiveOrder(_ liveIDs: [String], to savedIDs: [String]) -> [String] {
        var seenLive = Set<String>()
        let uniqueLive = liveIDs.filter { seenLive.insert($0).inserted }
        let liveSet = Set(uniqueLive)

        var seenSaved = Set<String>()
        var result = savedIDs.filter { seenSaved.insert($0).inserted }
        let visibleSlots = result.indices.filter { liveSet.contains(result[$0]) }

        var liveIndex = uniqueLive.startIndex
        for slot in visibleSlots {
            guard liveIndex < uniqueLive.endIndex else { break }
            result[slot] = uniqueLive[liveIndex]
            uniqueLive.formIndex(after: &liveIndex)
        }

        if liveIndex < uniqueLive.endIndex {
            result.append(contentsOf: uniqueLive[liveIndex...])
        }

        return result
    }

    static func persisting(
        visibleRailIDs: [String],
        visibleNonRailIDs: [String],
        savedIDs: [String]
    ) -> [String] {
        let visibleNonRail = Set(visibleNonRailIDs)
        let pruned = savedIDs.filter { !visibleNonRail.contains($0) }
        return appendingNewIDs(visibleIDs: visibleRailIDs, savedIDs: pruned)
    }
}

enum ExtensionTopbarPlacement {
    static func railItems(from items: [ExtensionStore.TopbarItemBinding]) -> [ExtensionStore.TopbarItemBinding] {
        items.filter(\.isRailEligible)
    }

    static func titleBarItems(
        from items: [ExtensionStore.TopbarItemBinding],
        railEnabled: Bool
    ) -> [ExtensionStore.TopbarItemBinding] {
        guard railEnabled else { return items }
        return items.filter { !$0.isRailEligible }
    }
}
