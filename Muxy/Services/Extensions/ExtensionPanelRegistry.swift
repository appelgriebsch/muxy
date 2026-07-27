import Foundation

struct ExtensionPanelSnapshot: Equatable {
    let extensionID: String
    let panelID: String
    let position: PanelPosition
    let mode: PanelMode
    let initialData: ExtensionJSON?
}

@MainActor
@Observable
final class ExtensionPanelRegistry {
    static let shared = ExtensionPanelRegistry()

    private(set) var openStates: [ExtensionPanelState] = []
    private(set) var activeProjectID: UUID?
    private var snapshotsByProject: [UUID: [ExtensionPanelSnapshot]] = [:]

    init() {
        PanelHost.shared.onDisplace = { [weak self] _ in self?.pruneClosed() }
    }

    func state(forHostPanelID hostPanelID: String) -> ExtensionPanelState? {
        openStates.first { $0.hostPanelID == hostPanelID }
    }

    func activateProject(_ projectID: UUID?, from previousProjectID: UUID?) {
        if previousProjectID == projectID, activeProjectID == projectID {
            return
        }

        if let previousProjectID {
            snapshotsByProject[previousProjectID] = captureLiveSnapshots()
        }

        clearLiveExtensionPanels(restoreFocus: false)
        activeProjectID = projectID

        guard let projectID else { return }
        let snapshots = snapshotsByProject.removeValue(forKey: projectID) ?? []
        for snapshot in snapshots {
            restore(snapshot)
        }
    }

    func purgeProject(_ projectID: UUID) {
        snapshotsByProject.removeValue(forKey: projectID)
        guard activeProjectID == projectID else { return }
        clearLiveExtensionPanels(restoreFocus: false)
        activeProjectID = nil
    }

    @discardableResult
    func open(
        extensionID: String,
        panel: ExtensionPanel,
        data: ExtensionJSON?,
        position: PanelPosition? = nil,
        mode: PanelMode? = nil
    ) -> ExtensionPanelState {
        let hostPanelID = ExtensionPanelState.hostPanelID(extensionID: extensionID, panelID: panel.id)
        openStates.removeAll { $0.hostPanelID == hostPanelID }
        let state = ExtensionPanelState(
            extensionID: extensionID,
            panelID: panel.id,
            initialData: data ?? panel.defaultData
        )
        openStates.append(state)
        PanelHost.shared.open(
            hostPanelID,
            at: position ?? panel.position,
            mode: mode ?? panel.mode
        )
        ExtensionLifecycleEvents.panelOpened(extensionID: extensionID, panelID: panel.id)
        return state
    }

    func toggle(extensionID: String, panel: ExtensionPanel, data: ExtensionJSON?) {
        let hostPanelID = ExtensionPanelState.hostPanelID(extensionID: extensionID, panelID: panel.id)
        if PanelHost.shared.isOpen(hostPanelID) {
            forceClose(hostPanelID: hostPanelID)
            return
        }
        open(extensionID: extensionID, panel: panel, data: data)
    }

    func setMode(_ mode: PanelMode, forHostPanelID hostPanelID: String) {
        PanelHost.shared.setMode(mode, for: hostPanelID)
    }

    func move(_ position: PanelPosition, forHostPanelID hostPanelID: String) {
        PanelHost.shared.move(hostPanelID, to: position)
    }

    func close(hostPanelID: String) {
        guard let state = state(forHostPanelID: hostPanelID) else {
            PanelFocusRestoration.shared.restoreAfterClosing(panelID: hostPanelID)
            PanelHost.shared.close(hostPanelID)
            return
        }
        let surfaceKey = LifecycleSurfaceKey(kind: .panel, instanceID: state.id.uuidString)
        Task { @MainActor in
            let verdict = await ExtensionSurfaceBridgeRegistry.shared.requestBeforeClose(surfaceKey)
            guard verdict == .allow,
                  self.state(forHostPanelID: hostPanelID)?.id == state.id
            else { return }
            forceClose(hostPanelID: hostPanelID)
        }
    }

    func forceClose(hostPanelID: String, restoreFocus: Bool = true) {
        let closed = openStates.filter { $0.hostPanelID == hostPanelID }
        if restoreFocus {
            PanelFocusRestoration.shared.restoreAfterClosing(panelID: hostPanelID)
        } else {
            PanelFocusRestoration.shared.discard(panelID: hostPanelID)
        }
        PanelHost.shared.close(hostPanelID)
        openStates.removeAll { $0.hostPanelID == hostPanelID }
        for state in closed {
            ExtensionLifecycleEvents.panelClosed(extensionID: state.extensionID, panelID: state.panelID)
        }
    }

    func forceClose(instanceID: String) {
        guard let state = openStates.first(where: { $0.id.uuidString == instanceID }) else { return }
        forceClose(hostPanelID: state.hostPanelID)
    }

    func closeAll(extensionID: String) {
        let closed = openStates.filter { $0.extensionID == extensionID }
        for state in closed {
            PanelFocusRestoration.shared.restoreAfterClosing(panelID: state.hostPanelID)
            PanelHost.shared.close(state.hostPanelID)
        }
        openStates.removeAll { $0.extensionID == extensionID }
        for state in closed {
            ExtensionLifecycleEvents.panelClosed(extensionID: state.extensionID, panelID: state.panelID)
        }
        for projectID in Array(snapshotsByProject.keys) {
            guard var snapshots = snapshotsByProject[projectID] else { continue }
            snapshots.removeAll { $0.extensionID == extensionID }
            if snapshots.isEmpty {
                snapshotsByProject.removeValue(forKey: projectID)
            } else {
                snapshotsByProject[projectID] = snapshots
            }
        }
    }

    func captureLiveSnapshots() -> [ExtensionPanelSnapshot] {
        openStates.compactMap { state in
            guard let placement = PanelHost.shared.placement(for: state.hostPanelID) else { return nil }
            return ExtensionPanelSnapshot(
                extensionID: state.extensionID,
                panelID: state.panelID,
                position: placement.position,
                mode: placement.mode,
                initialData: state.initialData
            )
        }
    }

    private func restore(_ snapshot: ExtensionPanelSnapshot) {
        guard let panel = panelForRestore(snapshot) else { return }
        open(
            extensionID: snapshot.extensionID,
            panel: panel,
            data: snapshot.initialData,
            position: snapshot.position,
            mode: snapshot.mode
        )
    }

    private func panelForRestore(_ snapshot: ExtensionPanelSnapshot) -> ExtensionPanel? {
        if let panel = ExtensionStore.shared.loadedExtension(id: snapshot.extensionID)?
            .manifest.panel(id: snapshot.panelID)
        {
            return panel
        }
        if ExtensionStore.shared.hasLoadedFromDisk {
            return nil
        }
        return ExtensionPanel(
            id: snapshot.panelID,
            entry: "index.html",
            position: snapshot.position,
            mode: snapshot.mode,
            defaultData: snapshot.initialData
        )
    }

    private func clearLiveExtensionPanels(restoreFocus: Bool) {
        let closed = openStates
        for state in closed {
            if restoreFocus {
                PanelFocusRestoration.shared.restoreAfterClosing(panelID: state.hostPanelID)
            } else {
                PanelFocusRestoration.shared.discard(panelID: state.hostPanelID)
            }
            PanelHost.shared.close(state.hostPanelID)
        }
        openStates = []
        for state in closed {
            ExtensionLifecycleEvents.panelClosed(extensionID: state.extensionID, panelID: state.panelID)
        }
    }

    private func pruneClosed() {
        let closed = openStates.filter { !PanelHost.shared.isOpen($0.hostPanelID) }
        for state in closed {
            PanelFocusRestoration.shared.restoreAfterClosing(panelID: state.hostPanelID)
        }
        openStates.removeAll { !PanelHost.shared.isOpen($0.hostPanelID) }
        for state in closed {
            ExtensionLifecycleEvents.panelClosed(extensionID: state.extensionID, panelID: state.panelID)
        }
    }
}
