import SwiftUI

struct ExtensionTopbarItems: View {
    @Environment(ExtensionStore.self) private var extensionStore

    var body: some View {
        ForEach(extensionStore.topbarItems) { binding in
            ExtensionTopbarItemControl(binding: binding, preferredEdge: .maxY)
        }
    }
}

struct ExtensionTopbarItemControl: View {
    let binding: ExtensionStore.TopbarItemBinding
    var preferredEdge: NSRectEdge = .maxY

    @Environment(AppState.self) private var appState
    @Environment(ProjectStore.self) private var projectStore
    @Environment(WorktreeStore.self) private var worktreeStore
    @Environment(ProjectGroupStore.self) private var projectGroupStore
    @Environment(BrowserProfileStore.self) private var browserProfileStore: BrowserProfileStore?
    @Environment(ExtensionStore.self) private var extensionStore
    @State private var popoverHost = PopoverHost.shared

    var body: some View {
        ExtensionIconButton(
            icon: binding.displayIcon,
            muxyExtension: binding.muxyExtension,
            accessibilityLabel: binding.item.tooltip ?? binding.item.id,
            action: { triggerCommand() }
        )
        .help(binding.item.tooltip ?? binding.item.id)
        .extensionPopover(anchorID: binding.id, host: popoverHost, preferredEdge: preferredEdge)
    }

    private func triggerCommand() {
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
