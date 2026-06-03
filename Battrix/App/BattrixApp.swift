import SwiftUI
import SwiftData

@main
struct BattrixApp: App {
    @State private var model = BatteryViewModel()

    /// Local-only history store. SwiftData backs the trend charts; nothing leaves the device.
    ///
    /// Nil under XCTest: the unit-test target creates its own in-memory container, and a second
    /// container for the same `@Model` in the host process trips a SwiftData trap. When hosted by
    /// tests we skip SwiftData entirely and render an empty view — tests drive the code directly.
    private let container: ModelContainer?

    init() {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            container = nil
        } else {
            container = try? ModelContainer(for: HistorySample.self)
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView(model: model, container: container)
                .frame(minWidth: 420, minHeight: 560)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 440, height: 640)

        MenuBarExtra {
            MenuBarRoot(model: model, container: container)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Main window content. Attaches SwiftData + starts the refresh loop only when a container exists
/// (i.e. not under test). `@ViewBuilder` supports the conditional that `SceneBuilder` cannot.
private struct RootView: View {
    let model: BatteryViewModel
    let container: ModelContainer?

    var body: some View {
        if let container {
            ContentView()
                .environment(model)
                .modelContainer(container)
                .task {
                    model.attach(history: HistoryStore(context: container.mainContext))
                    model.start()
                }
        } else {
            EmptyView()
        }
    }
}

/// Menu-bar popover content, gated on the same container.
private struct MenuBarRoot: View {
    let model: BatteryViewModel
    let container: ModelContainer?

    var body: some View {
        if let container {
            MenuBarView()
                .environment(model)
                .modelContainer(container)
        } else {
            EmptyView()
        }
    }
}
