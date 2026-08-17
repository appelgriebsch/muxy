import SwiftUI

struct ExtensionTopbarItems: View {
    @Environment(ExtensionStore.self) private var extensionStore
    @AppStorage(TopbarPreferences.railVisibleKey)
    private var showExtensionIconRail = TopbarPreferences.defaultRailVisible

    var body: some View {
        ForEach(
            ExtensionTopbarPlacement.titleBarItems(
                from: extensionStore.topbarItems,
                railEnabled: showExtensionIconRail
            )
        ) { binding in
            ExtensionTopbarItemControl(binding: binding)
        }
    }
}

struct ExtensionTopbarItemControl: View {
    let binding: ExtensionStore.TopbarItemBinding
    var isCommandEnabled = true
    var showsSelectionChrome = false

    @Environment(AppState.self) private var appState
    @Environment(ProjectStore.self) private var projectStore
    @Environment(WorktreeStore.self) private var worktreeStore
    @Environment(ProjectGroupStore.self) private var projectGroupStore
    @Environment(BrowserProfileStore.self) private var browserProfileStore: BrowserProfileStore?
    @Environment(ExtensionStore.self) private var extensionStore
    @State private var popoverHost = PopoverHost.shared
    @State private var panelRegistry = ExtensionPanelRegistry.shared

    private var isActive: Bool {
        if popoverHost.isOpen(anchorID: binding.id) {
            return true
        }
        guard let panelID = togglePanelID else { return false }
        return panelRegistry.state(
            forHostPanelID: ExtensionPanelState.hostPanelID(
                extensionID: binding.muxyExtension.id,
                panelID: panelID
            )
        ) != nil
    }

    private var showsActiveChrome: Bool {
        showsSelectionChrome && isActive
    }

    private var togglePanelID: String? {
        guard let command = binding.muxyExtension.manifest.commands.first(where: { $0.id == binding.item.command }),
              case let .togglePanel(panel) = command.action
        else { return nil }
        return panel
    }

    var body: some View {
        ExtensionIconButton(
            icon: binding.displayIcon,
            muxyExtension: binding.muxyExtension,
            color: showsActiveChrome ? MuxyTheme.fg : MuxyTheme.fgMuted,
            hoverColor: MuxyTheme.fg,
            isEnabled: isCommandEnabled,
            accessibilityLabel: binding.item.tooltip ?? binding.item.id,
            action: { triggerCommand() }
        )
        .overlay {
            RoundedRectangle(cornerRadius: UIMetrics.radiusMD, style: .continuous)
                .strokeBorder(showsActiveChrome ? MuxyTheme.accent : .clear, lineWidth: 1.5)
                .padding(UIMetrics.spacing1)
                .animation(.easeInOut(duration: 0.15), value: showsActiveChrome)
        }
        .help(binding.item.tooltip ?? binding.item.id)
        .accessibilityValue(isActive ? L10n.string("Active") : "")
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .extensionPopover(anchorID: binding.id, host: popoverHost)
    }

    private func triggerCommand() {
        guard isCommandEnabled else { return }
        if let popover = extensionStore.popover(for: binding.muxyExtension, command: binding.item.command) {
            popoverHost.toggle(
                anchorID: binding.id,
                extensionID: binding.muxyExtension.id,
                popover: popover,
                data: nil
            )
            return
        }
        extensionStore.triggerCommand(
            ExtensionStore.CommandInvocation(
                extensionID: binding.muxyExtension.id,
                commandID: binding.item.command,
                appState: appState,
                projectStore: projectStore,
                worktreeStore: worktreeStore,
                projectGroupStore: projectGroupStore,
                browserProfileStore: browserProfileStore
            )
        )
    }
}
