import Foundation
import Testing

@testable import Muxy

@Suite("Extension bar item overrides")
@MainActor
struct ExtensionBarItemOverrideTests {
    @Test("ExtensionIcon.parse reads bare symbol strings")
    func parsesBareSymbol() {
        #expect(ExtensionIcon.parse("hammer.fill") == .symbol("hammer.fill"))
    }

    @Test("ExtensionIcon.parse reads symbol and svg objects")
    func parsesIconObjects() {
        #expect(ExtensionIcon.parse(["symbol": "bolt"]) == .symbol("bolt"))
        #expect(ExtensionIcon.parse(["svg": "badge.svg"]) == .svg("badge.svg"))
    }

    @Test("ExtensionIcon.parse rejects empty and malformed input")
    func parsesInvalidIcon() {
        #expect(ExtensionIcon.parse("") == nil)
        #expect(ExtensionIcon.parse(["symbol": ""]) == nil)
        #expect(ExtensionIcon.parse(["color": "red"]) == nil)
        #expect(ExtensionIcon.parse(nil) == nil)
    }

    @Test("topbar binding prefers the live icon over the manifest icon")
    func topbarDisplayIconFallback() {
        let item = ExtensionTopbarItem(id: "i", icon: .symbol("a"), tooltip: nil, command: "c")
        let base = ExtensionStore.TopbarItemBinding(muxyExtension: ext, item: item, liveIcon: nil, liveVisible: nil)
        let overridden = ExtensionStore.TopbarItemBinding(
            muxyExtension: ext,
            item: item,
            liveIcon: .symbol("b"),
            liveVisible: nil
        )
        #expect(base.displayIcon == .symbol("a"))
        #expect(overridden.displayIcon == .symbol("b"))
    }

    @Test("topbar binding visibility prefers the live override over the manifest default")
    func topbarVisibilityFallback() {
        let visible = ExtensionTopbarItem(id: "i", icon: .symbol("a"), tooltip: nil, command: "c")
        let hidden = ExtensionTopbarItem(id: "i", icon: .symbol("a"), tooltip: nil, command: "c", visible: false)
        #expect(ExtensionStore.TopbarItemBinding(muxyExtension: ext, item: visible, liveIcon: nil, liveVisible: nil)
            .isVisible)
        #expect(!ExtensionStore.TopbarItemBinding(muxyExtension: ext, item: hidden, liveIcon: nil, liveVisible: nil)
            .isVisible)
        #expect(ExtensionStore.TopbarItemBinding(muxyExtension: ext, item: hidden, liveIcon: nil, liveVisible: true)
            .isVisible)
    }

    @Test("status bar binding visibility prefers the live override over the manifest default")
    func statusBarVisibilityFallback() {
        let visible = ExtensionStatusBarItem(id: "i", icon: .symbol("a"), text: nil, tooltip: nil, side: .right, command: "c")
        let hidden = ExtensionStatusBarItem(
            id: "i",
            icon: .symbol("a"),
            text: nil,
            tooltip: nil,
            side: .right,
            command: "c",
            visible: false
        )
        #expect(binding(visible, liveVisible: nil).isVisible)
        #expect(!binding(hidden, liveVisible: nil).isVisible)
        #expect(binding(hidden, liveVisible: true).isVisible)
        #expect(!binding(visible, liveVisible: false).isVisible)
    }

    @Test("topbar item defaults visible to true and decodes an explicit false")
    func topbarVisibilityDecodes() throws {
        let shown = try decodeTopbarItem(#"{ "id": "i", "icon": "a", "command": "c" }"#)
        let hidden = try decodeTopbarItem(#"{ "id": "i", "icon": "a", "command": "c", "visible": false }"#)
        #expect(shown.visible)
        #expect(!hidden.visible)
    }

    @Test("status bar item defaults visible to true and decodes an explicit false")
    func statusBarVisibilityDecodes() throws {
        let shown = try decodeStatusBarItem(#"{ "id": "i", "icon": "a", "side": "right", "command": "c" }"#)
        let hidden = try decodeStatusBarItem(#"{ "id": "i", "icon": "a", "side": "right", "command": "c", "visible": false }"#)
        #expect(shown.visible)
        #expect(!hidden.visible)
    }

    @Test("togglePanel is rail eligible; other actions and missing commands are not")
    func railEligibility() {
        #expect(ExtensionCommandAction.togglePanel(panel: "p").isRailEligible)
        #expect(!ExtensionCommandAction.openPopover(popover: "p").isRailEligible)
        #expect(!ExtensionCommandAction.event.isRailEligible)
        #expect(!ExtensionCommandAction.openTab(tabType: "t", data: nil).isRailEligible)
        #expect(!ExtensionCommandAction.openModal(
            ExtensionModalAction(entry: "m.html", width: nil, height: nil, dismissOnOutsideClick: true, data: nil)
        ).isRailEligible)
        #expect(!ExtensionCommandAction.runScript(script: "s.js").isRailEligible)
        #expect(binding(command: "toggle", action: .togglePanel(panel: "p")).isRailEligible)
        #expect(!binding(command: "popover", action: .openPopover(popover: "p")).isRailEligible)
        #expect(!binding(command: "event", action: .event).isRailEligible)
        #expect(!binding(command: "tab", action: .openTab(tabType: "t", data: nil)).isRailEligible)
        #expect(!binding(
            command: "modal",
            action: .openModal(
                ExtensionModalAction(entry: "m.html", width: nil, height: nil, dismissOnOutsideClick: true, data: nil)
            )
        ).isRailEligible)
        #expect(!binding(command: "script", action: .runScript(script: "s.js")).isRailEligible)
        #expect(!binding(command: "missing", action: nil).isRailEligible)
    }

    @Test("status bar binding prefers live icon and text over the manifest values")
    func statusBarDisplayFallback() {
        let item = ExtensionStatusBarItem(id: "i", icon: .symbol("a"), text: "1", tooltip: nil, side: .right, command: "c")
        let base = ExtensionStore.StatusBarItemBinding(
            muxyExtension: ext,
            item: item,
            liveIcon: nil,
            liveText: nil,
            liveVisible: nil
        )
        let overridden = ExtensionStore.StatusBarItemBinding(
            muxyExtension: ext,
            item: item,
            liveIcon: .symbol("b"),
            liveText: "9",
            liveVisible: nil
        )
        #expect(base.displayIcon == .symbol("a"))
        #expect(base.displayText == "1")
        #expect(overridden.displayIcon == .symbol("b"))
        #expect(overridden.displayText == "9")
    }

    private func binding(command: String, action: ExtensionCommandAction?) -> ExtensionStore.TopbarItemBinding {
        let commands = action.map { [ExtensionPaletteCommand(id: command, title: command, action: $0)] } ?? []
        let muxyExtension = MuxyExtension(
            id: "demo",
            directory: URL(fileURLWithPath: "/tmp/demo"),
            manifest: ExtensionManifest(
                name: "demo",
                version: "1.0.0",
                background: "background.js",
                commands: commands
            )
        )
        return ExtensionStore.TopbarItemBinding(
            muxyExtension: muxyExtension,
            item: ExtensionTopbarItem(id: command, icon: .symbol("a"), tooltip: nil, command: command),
            liveIcon: nil,
            liveVisible: nil
        )
    }

    private func binding(_ item: ExtensionStatusBarItem, liveVisible: Bool?) -> ExtensionStore.StatusBarItemBinding {
        ExtensionStore.StatusBarItemBinding(
            muxyExtension: ext,
            item: item,
            liveIcon: nil,
            liveText: nil,
            liveVisible: liveVisible
        )
    }

    private func decodeTopbarItem(_ json: String) throws -> ExtensionTopbarItem {
        try JSONDecoder().decode(ExtensionTopbarItem.self, from: Data(json.utf8))
    }

    private func decodeStatusBarItem(_ json: String) throws -> ExtensionStatusBarItem {
        try JSONDecoder().decode(ExtensionStatusBarItem.self, from: Data(json.utf8))
    }

    private var ext: MuxyExtension {
        MuxyExtension(
            id: "demo",
            directory: URL(fileURLWithPath: "/tmp/demo"),
            manifest: ExtensionManifest(name: "demo", version: "1.0.0", background: "background.js")
        )
    }
}
