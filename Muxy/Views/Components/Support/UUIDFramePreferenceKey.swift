import SwiftUI

struct UUIDFramePreferenceKey<Tag>: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [UUID: CGRect] { [:] }
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct StringFramePreferenceKey<Tag>: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [String: CGRect] { [:] }
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

enum SidebarFrameTag {}
enum AreaFrameTag {}
enum TabFrameTag {}
enum ExtensionIconRailFrameTag {}
