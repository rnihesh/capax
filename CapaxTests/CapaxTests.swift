import Testing
@testable import Capax

/// Placeholder suite kept @MainActor so the whole target runs serially (see MacBatteryMathTests).
@MainActor
struct CapaxTests {
    @Test func appModuleLoads() {
        // Smoke test: the module imports and a core type constructs.
        #expect(MacBattery.empty.healthPercent == nil)
    }
}
