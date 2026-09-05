import LimitMeterCore
import SwiftUI

@main
struct LimitMeterApp: App {
    @State private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
                .task {
                    store.startPolling()
                }
        } label: {
            MenuBarLabelView(usage: store.menuBarUsage)
        }
        .menuBarExtraStyle(.window)
    }
}
