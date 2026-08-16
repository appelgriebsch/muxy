import SwiftUI

struct ExtensionPopoverAnchor: NSViewRepresentable {
    let anchorID: String
    let host: PopoverHost
    let state: ExtensionPopoverState?
    let width: Double?
    let height: Double?
    var preferredEdge: NSRectEdge = .maxY

    @Environment(AppState.self) private var appState
    @Environment(ProjectStore.self) private var projectStore
    @Environment(WorktreeStore.self) private var worktreeStore

    func makeCoordinator() -> ExtensionPopoverCoordinator {
        ExtensionPopoverCoordinator(
            anchorID: anchorID,
            host: host,
            preferredEdge: preferredEdge,
            appState: appState,
            projectStore: projectStore,
            worktreeStore: worktreeStore
        )
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.anchorView = view
        return view
    }

    func updateNSView(_: NSView, context: Context) {
        context.coordinator.sync(state: state)
    }

    static func dismantleNSView(_: NSView, coordinator: ExtensionPopoverCoordinator) {
        coordinator.tearDown()
    }
}

@MainActor
final class ExtensionPopoverCoordinator: NSObject, NSPopoverDelegate {
    private let anchorID: String
    private let host: PopoverHost
    private let preferredEdge: NSRectEdge
    private let appState: AppState
    private let projectStore: ProjectStore?
    private let worktreeStore: WorktreeStore?

    weak var anchorView: NSView?
    private var popover: NSPopover?
    private var presentedStateID: UUID?

    init(
        anchorID: String,
        host: PopoverHost,
        preferredEdge: NSRectEdge,
        appState: AppState,
        projectStore: ProjectStore?,
        worktreeStore: WorktreeStore?
    ) {
        self.anchorID = anchorID
        self.host = host
        self.preferredEdge = preferredEdge
        self.appState = appState
        self.projectStore = projectStore
        self.worktreeStore = worktreeStore
    }

    func sync(state: ExtensionPopoverState?) {
        guard let state else {
            close()
            return
        }
        guard presentedStateID != state.id else {
            resizeIfNeeded(to: state)
            return
        }
        present(state)
    }

    func tearDown() {
        close()
    }

    private func present(_ state: ExtensionPopoverState) {
        guard let anchorView, anchorView.window != nil else { return }
        close()

        let popover = NSPopover()
        popover.behavior = .semitransient
        popover.delegate = self
        let size = contentSize(for: state)
        popover.contentViewController = makeContentController(for: state, size: size)
        popover.contentSize = size
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: preferredEdge)

        self.popover = popover
        presentedStateID = state.id
    }

    private func close() {
        guard let popover else { return }
        popover.delegate = nil
        popover.performClose(nil)
        self.popover = nil
        presentedStateID = nil
    }

    private func resizeIfNeeded(to state: ExtensionPopoverState) {
        let size = contentSize(for: state)
        guard popover?.contentSize != size else { return }
        popover?.contentSize = size
        (popover?.contentViewController as? NSHostingController<AnyView>)?.rootView = hostedRootView(
            for: state,
            size: size
        )
    }

    private func makeContentController(
        for state: ExtensionPopoverState,
        size: NSSize
    ) -> NSHostingController<AnyView> {
        let controller = NSHostingController(rootView: hostedRootView(for: state, size: size))
        controller.preferredContentSize = size
        return controller
    }

    private func hostedRootView(for state: ExtensionPopoverState, size: NSSize) -> AnyView {
        AnyView(
            ExtensionPopoverView(state: state, size: size)
                .environment(appState)
                .environment(projectStore)
                .environment(worktreeStore)
        )
    }

    private func contentSize(for state: ExtensionPopoverState) -> NSSize {
        let remaining = remainingSpace()
        return ExtensionPopoverLayout.clampedContentSize(
            width: state.width,
            height: state.height,
            remainingOnEdge: remaining
        )
    }

    private func remainingSpace() -> CGSize? {
        guard let window = anchorView?.window else { return nil }
        return ExtensionPopoverLayout.remainingSpace(
            preferredEdge: preferredEdge,
            windowSize: window.frame.size
        )
    }

    func popoverDidClose(_: Notification) {
        popover = nil
        presentedStateID = nil
        host.close(anchorID: anchorID)
    }
}
