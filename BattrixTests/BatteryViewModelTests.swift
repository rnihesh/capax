import Testing
import Foundation
@testable import Battrix

/// Stubs let us drive the view model deterministically without IOKit or device tooling.
private struct StubMacSource: MacBatterySource {
    var result: (battery: MacBattery, adapter: AdapterInfo)?
    func read() -> (battery: MacBattery, adapter: AdapterInfo)? { result }
}

private struct StubIOSReader: IOSDeviceReader {
    var isToolingAvailable: Bool = true
    var state: DeviceConnection = .noDevice
    func poll() -> DeviceConnection { state }
}

@MainActor
struct BatteryViewModelTests {

    @Test func refreshPopulatesFromSource() {
        let mac = MacBattery(rawMaxCapacity: 4000, designCapacity: 5000)
        let vm = BatteryViewModel(
            macSource: StubMacSource(result: (mac, AdapterInfo(isConnected: true))),
            iosReader: StubIOSReader()
        )
        vm.refresh()
        #expect(vm.mac?.healthPercent == 80.0)
        #expect(vm.adapter.isConnected)
        #expect(vm.lastUpdated != nil)
    }

    @Test func refreshWithNoBatteryIsSafeEmptyState() {
        let vm = BatteryViewModel(macSource: StubMacSource(result: nil), iosReader: StubIOSReader())
        vm.refresh()
        #expect(vm.mac == nil)
        #expect(vm.adapter.isConnected == false)
    }

    @Test func pollSurfacesConnectedDevices() async {
        let device = IOSDeviceBattery(udid: "udid-1", designCapacity: 3300, fullChargeCapacity: 3000, cycleCount: 100)
        let vm = BatteryViewModel(
            macSource: StubMacSource(result: nil),
            iosReader: StubIOSReader(state: .connected([device]))
        )
        await vm.pollDevices()
        #expect(vm.devices.count == 1)
        #expect(vm.devices.first?.udid == "udid-1")
    }

    @Test func toolingMissingReflected() async {
        let vm = BatteryViewModel(
            macSource: StubMacSource(result: nil),
            iosReader: StubIOSReader(isToolingAvailable: false, state: .toolingMissing)
        )
        await vm.pollDevices()
        #expect(vm.isToolingAvailable == false)
        #expect(vm.connection == .toolingMissing)
        #expect(vm.devices.isEmpty)
    }

    @Test func stopPreventsLeakAfterStart() {
        let vm = BatteryViewModel(macSource: StubMacSource(result: nil), iosReader: StubIOSReader())
        vm.start()
        vm.stop()
        // After stop, a manual refresh still works (no crash, timer gone).
        vm.refresh()
        #expect(vm.lastUpdated != nil)
    }
}
