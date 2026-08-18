import SwiftUI

@main
struct AIUsageBarApp: App {
    var body: some Scene {
        MenuBarExtra("AI 用量", systemImage: "chart.bar.fill") {
            UsagePanelView()
        }
        .menuBarExtraStyle(.window)
    }
}
