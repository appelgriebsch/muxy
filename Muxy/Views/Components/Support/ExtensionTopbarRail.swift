import SwiftUI

struct ExtensionTopbarRail: View {
    @Environment(ExtensionStore.self) private var extensionStore
    @State private var orderStore = ExtensionTopbarRailOrderStore.shared

    var body: some View {
        let items = ExtensionTopbarRailOrder.displayed(
            visible: extensionStore.topbarItems,
            savedIDs: orderStore.ids
        )
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: UIMetrics.spacing3) {
                ForEach(items) { binding in
                    ExtensionTopbarItemControl(binding: binding, preferredEdge: .minX)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, UIMetrics.spacing2)
        }
        .onAppear(perform: persistFirstSeenIDs)
        .onChange(of: extensionStore.topbarItems) { _, _ in
            persistFirstSeenIDs()
        }
    }

    private func persistFirstSeenIDs() {
        orderStore.ids = ExtensionTopbarRailOrder.appendingNewIDs(
            visibleIDs: extensionStore.topbarItems.map(\.id),
            savedIDs: orderStore.ids
        )
    }
}
