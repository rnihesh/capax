import Foundation

/// Production `IOSDeviceReader` that shells out to the libimobiledevice CLI tools.
///
/// Tool resolution order:
///   1. bundled in `Capax.app/Contents/Resources/idevice/` (release builds)
///   2. common Homebrew locations + `PATH` (source/dev builds)
///
/// Only thin Process invocation lives here; all output parsing is in `IOSPlistParsing` and is
/// unit-tested against fixtures. Reads health/cycles from the device's `AppleSmartBattery`
/// IORegistry entry (fallback `AppleARMPMUCharger` for iPhone 7 and older).
struct LibimobiledeviceReader: IOSDeviceReader {

    private let toolDir: String?

    init() {
        self.toolDir = Self.locateToolDirectory()
    }

    var isToolingAvailable: Bool { toolDir != nil }

    func poll() -> DeviceConnection {
        guard toolDir != nil else { return .toolingMissing }

        let udids: [String]
        do {
            udids = try listUDIDs()
        } catch {
            return .failed("Could not list devices: \(error.localizedDescription)")
        }
        guard !udids.isEmpty else { return .noDevice }

        var devices: [IOSDeviceBattery] = []
        for udid in udids {
            var device = IOSDeviceBattery(udid: udid)

            // Identity. A pairing/trust error here means the device isn't trusted yet.
            switch runTool("ideviceinfo", ["-u", udid, "-x"]) {
            case .success(let data):
                IOSPlistParsing.applyDeviceInfo(data, into: &device)
            case .failure(let err):
                if err.looksLikeTrustError { return .detectedUntrusted(udid: udid) }
            }

            // Battery via diagnostics relay IORegistry, with the legacy-device fallback entry.
            if case .success(let data) = runTool("idevicediagnostics", ["-u", udid, "ioregentry", "AppleSmartBattery"]) {
                if IOSPlistParsing.isBatteryEntryEmpty(data),
                   case .success(let legacy) = runTool("idevicediagnostics", ["-u", udid, "ioregentry", "AppleARMPMUCharger"]) {
                    IOSPlistParsing.applyBatteryIORegistry(legacy, into: &device)
                } else {
                    IOSPlistParsing.applyBatteryIORegistry(data, into: &device)
                }
            }

            devices.append(device)
        }
        return .connected(devices)
    }

    // MARK: - Process plumbing

    private func listUDIDs() throws -> [String] {
        guard case .success(let data) = runTool("idevice_id", ["-l"]),
              let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private enum ToolError: Error {
        case notFound
        case nonZero(code: Int32, stderr: String)
        var looksLikeTrustError: Bool {
            if case .nonZero(_, let stderr) = self {
                let s = stderr.lowercased()
                return s.contains("trust") || s.contains("pair") || s.contains("not paired") || s.contains("escrow")
            }
            return false
        }
    }

    private func runTool(_ name: String, _ args: [String]) -> Result<Data, ToolError> {
        guard let dir = toolDir else { return .failure(.notFound) }
        let path = (dir as NSString).appendingPathComponent(name)
        guard FileManager.default.isExecutableFile(atPath: path) else { return .failure(.notFound) }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        let out = Pipe(), err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return .failure(.notFound)
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        if proc.terminationStatus != 0 {
            let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return .failure(.nonZero(code: proc.terminationStatus, stderr: stderr))
        }
        return .success(data)
    }

    // MARK: - Tool location

    private static func locateToolDirectory() -> String? {
        let fm = FileManager.default
        var candidates: [String] = []
        if let resource = Bundle.main.resourceURL?.appendingPathComponent("idevice").path {
            candidates.append(resource)
        }
        candidates += ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
        for dir in candidates {
            if fm.isExecutableFile(atPath: (dir as NSString).appendingPathComponent("idevice_id")) {
                return dir
            }
        }
        return nil
    }
}
