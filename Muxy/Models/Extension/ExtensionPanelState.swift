import Foundation

@MainActor
@Observable
final class ExtensionPanelState: Identifiable {
    let id = UUID()
    let extensionID: String
    let panelID: String
    let initialData: ExtensionJSON?
    let panel: ExtensionPanel

    init(
        extensionID: String,
        panel: ExtensionPanel,
        initialData: ExtensionJSON? = nil
    ) {
        self.extensionID = extensionID
        self.panelID = panel.id
        self.initialData = initialData
        self.panel = panel
    }

    var hostPanelID: String { ExtensionPanelState.hostPanelID(extensionID: extensionID, panelID: panelID) }

    nonisolated static func hostPanelID(extensionID: String, panelID: String) -> String {
        "ext:\(extensionID):\(panelID)"
    }
}
