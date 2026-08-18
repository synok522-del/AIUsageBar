import SwiftUI

@main
struct AIUsageBarApp: App {
    @StateObject private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            UsagePanelView(viewModel: viewModel)
        } label: {
            MenuBarStatusView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
