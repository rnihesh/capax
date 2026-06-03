import Foundation
import Observation

/// Single source of truth for the UI. Owns the refresh loop, the current Mac/adapter/iOS readings,
/// and history sampling. Both the window and the menu bar observe this one instance.
@MainActor
@Observable
final class BatteryViewModel {
    private(set) var mac: MacBattery?
    private(set) var adapter: AdapterInfo = .disconnected
    private(set) var connection: DeviceConnection = .noDevice
    private(set) var lastUpdated: Date?

    /// Live readout cadence (seconds). iOS devices are polled less often (Process spawning is heavier).
    var liveInterval: TimeInterval = 5
    private let iosPollEveryNTicks = 6

    private let macSource: MacBatterySource
    private let iosReader: IOSDeviceReader
    private var history: HistoryStore?
    private var timer: Timer?
    private var tick = 0

    init(macSource: MacBatterySource = MacBatteryService(),
         iosReader: IOSDeviceReader = LibimobiledeviceReader()) {
        self.macSource = macSource
        self.iosReader = iosReader
    }

    /// Attach the persistence store once the SwiftData container exists.
    func attach(history: HistoryStore) {
        self.history = history
    }

    func start() {
        refresh()
        pollDevices()
        timer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: liveInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.onTick() }
        }
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func onTick() {
        refresh()
        tick += 1
        if tick % iosPollEveryNTicks == 0 { pollDevices() }
    }

    /// Pull a fresh Mac reading and record history.
    func refresh() {
        if let reading = macSource.read() {
            mac = reading.battery
            adapter = reading.adapter
        } else {
            mac = nil
            adapter = .disconnected
        }
        lastUpdated = Date()
        recordHistory()
    }

    /// Poll connected iOS devices (separate cadence).
    func pollDevices() {
        connection = iosReader.poll()
        recordDeviceHistory()
    }

    var isToolingAvailable: Bool { iosReader.isToolingAvailable }

    /// Connected devices, if any (convenience for views).
    var devices: [IOSDeviceBattery] {
        if case .connected(let list) = connection { return list }
        return []
    }

    // MARK: - History

    private func recordHistory() {
        guard let history, let mac else { return }
        history.record(HistorySample(
            timestamp: Date(),
            source: "mac",
            healthPercent: mac.healthPercent,
            maxCapacity: mac.rawMaxCapacity,
            cycleCount: mac.cycleCount,
            temperatureC: mac.temperatureC,
            chargePercent: mac.chargePercent
        ))
    }

    private func recordDeviceHistory() {
        guard let history else { return }
        for d in devices {
            history.record(HistorySample(
                timestamp: Date(),
                source: d.udid,
                healthPercent: d.healthPercent,
                maxCapacity: d.fullChargeCapacity,
                cycleCount: d.cycleCount,
                temperatureC: d.temperatureC,
                chargePercent: d.chargePercent
            ))
        }
    }
}
