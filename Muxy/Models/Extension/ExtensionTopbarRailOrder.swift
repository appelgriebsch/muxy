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
        var liveIndex = uniqueLive.startIndex
        var used = Set<String>()
        var result: [String] = []
        result.reserveCapacity(savedIDs.count + uniqueLive.count)

        for id in savedIDs {
            if used.contains(id) {
                continue
            }
            if liveSet.contains(id) {
                guard liveIndex < uniqueLive.endIndex else { continue }
                let next = uniqueLive[liveIndex]
                uniqueLive.formIndex(after: &liveIndex)
                used.insert(next)
                result.append(next)
                continue
            }
            used.insert(id)
            result.append(id)
        }

        while liveIndex < uniqueLive.endIndex {
            let next = uniqueLive[liveIndex]
            uniqueLive.formIndex(after: &liveIndex)
            if used.insert(next).inserted {
                result.append(next)
            }
        }

        return result
    }
}
