# Battrix

**A native macOS battery monitor — for your Mac *and* your iPhone & iPad.**

Battrix reads detailed battery and power data straight from your hardware and presents it in a clean, minimal, native interface. Check battery health, capacity, cycle count, temperature, and power draw at a glance — from a menu-bar popover or a full window — and read the battery health of any connected iPhone or iPad over USB.

It's everything you'd reach a tool like coconutBattery for, plus connected-device health and local history graphs, in one menu-bar-native app. Fully offline. No account. No telemetry.

![Battrix — dark](./Assets/dark.png)
![Battrix — light](./Assets/light.png)

> Screenshots above show an earlier build and will be refreshed for the new UI.

## Features

### Your Mac
- **Battery health** — current full-charge capacity vs. factory design capacity, shown as one clear hero metric with a custom gauge.
- **Capacity** — full charge, design, and current charge (mAh).
- **Condition** — cycle count, temperature, instantaneous power (W), voltage, amperage.
- **Power adapter** — wattage, name, manufacturer, voltage, current, serial.
- **Identity** — battery serial and ID.

### Your iPhone & iPad
- Connect a device over **USB** to read its **battery health, cycle count, full-charge & design capacity, charge level, and temperature** — the numbers Apple buries or doesn't show at all.
- Honest, explicit states: connect a device, trust the computer, or install the tools — Battrix always tells you what it needs, and **never fakes or "repairs" a health number.**

### History
- Battrix records samples locally while it runs and charts **health, capacity, cycle count, and temperature trends** over time with Swift Charts.
- All history stays on your device.

### Menu bar
- A always-glanceable menu-bar item shows live charge % and watts, with a popover summary and a button to open the full window.

## Requirements

- macOS 15.5 or later
- A Mac with a battery (for Mac readings) and/or a USB-connected iPhone/iPad (for device readings)

## Install

### From a release
1. Download the latest `Battrix.dmg` from [Releases](https://github.com/rnihesh/battrix/releases).
2. Drag **Battrix** to Applications and launch it.

Release builds bundle the device-reading tools — no extra setup for iPhone/iPad support.

### Build from source
1. Clone and open:
   ```bash
   git clone https://github.com/rnihesh/battrix.git
   cd battrix
   open Battrix.xcodeproj
   ```
2. Build & run (⌘R).
3. For iPhone/iPad reading in a source build, install the device tools once:
   ```bash
   brew install libimobiledevice
   ```
   Battrix finds them automatically (bundled first, then Homebrew/`PATH`).

## How it works

- **Mac battery** comes from the IOKit `AppleSmartBattery` service. Battrix reads the raw registry properties and computes health (`AppleRawMaxCapacity ÷ DesignCapacity`), charge, and power locally.
- **iPhone/iPad battery** is read over USB using [libimobiledevice](https://libimobiledevice.org): Battrix queries the device's own `AppleSmartBattery` IORegistry entry through the diagnostics relay (with an `AppleARMPMUCharger` fallback for iPhone 7 and older) and computes health from the raw capacity values. The device must be unlocked and set to **trust** this computer.
- **History** is stored locally with SwiftData and charted with Swift Charts.

## Privacy

Battrix is fully offline. It reads battery data locally and keeps it on your device — no collection, no transmission, no account.

## Roadmap

- Wi-Fi reading for paired iOS devices (cable-free)
- iCloud history sync across your Macs
- Per-device low-battery notifications

## Contributing

Bug reports, feature ideas, and pull requests are welcome.

## License

MIT — see [LICENSE](./LICENSE).

---

Made with ❤️ by Nihesh
