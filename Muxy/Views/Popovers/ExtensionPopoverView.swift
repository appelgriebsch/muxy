import SwiftUI

struct ExtensionPopoverView: View {
    let state: ExtensionPopoverState

    @Environment(AppState.self) private var appState
    @Environment(ProjectStore.self) private var projectStore
    @Environment(WorktreeStore.self) private var worktreeStore
    @Environment(ProjectGroupStore.self) private var projectGroupStore

    var body: some View {
        Group {
            if let muxyExtension = ExtensionStore.shared.loadedExtension(id: state.extensionID),
               let popover = muxyExtension.manifest.popover(id: state.popoverID),
               let entryURL = ExtensionWebView.entryURL(for: muxyExtension, entry: popover.entry)
            {
                ExtensionWebView(
                    extensionID: muxyExtension.id,
                    instanceID: state.id.uuidString,
                    surfaceKind: .popover,
                    entryURL: entryURL,
                    initialData: state.initialData,
                    appState: appState,
                    projectStore: projectStore,
                    worktreeStore: worktreeStore,
                    projectGroupStore: projectGroupStore,
                    focused: true
                )
            } else {
                Color.clear
            }
        }
        .frame(width: state.width, height: state.height)
    }
}

extension View {
    func extensionPopover(
        anchorID: String,
        host: PopoverHost,
        preferredEdge: NSRectEdge = .maxY
    ) -> some View {
        modifier(ExtensionPopoverModifier(
            anchorID: anchorID,
            host: host,
            preferredEdge: preferredEdge
        ))
    }
}

private struct ExtensionPopoverModifier: ViewModifier {
    let anchorID: String
    let host: PopoverHost
    let preferredEdge: NSRectEdge

    func body(content: Content) -> some View {
        let state = host.isOpen(anchorID: anchorID) ? host.open?.state : nil
        return content.background(
            ExtensionPopoverAnchor(
                anchorID: anchorID,
                host: host,
                state: state,
                width: state?.width,
                height: state?.height,
                preferredEdge: preferredEdge
            )
            .allowsHitTesting(false)
        )
    }
}
