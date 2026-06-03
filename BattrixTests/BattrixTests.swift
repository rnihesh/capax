import Testing
@testable import Battrix

/// Placeholder suite kept @MainActor so the whole target runs serially (see MacBatteryMathTests).
@MainActor
struct BattrixTests {
    @Test func appModuleLoads() {
        // Smoke test: the module imports and a core type constructs.
        #expect(MacBattery.empty.healthPercent == nil)
    }
}
