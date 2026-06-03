# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What Battrix is

Native macOS SwiftUI app that reads battery and power-adapter telemetry from the Mac's hardware and displays it. Goal: surpass coconutBattery / coconutBattery Pro (battery health, cycles, capacity, adapter, and connected-iOS-device battery info).

## Build / run / test

No package manager — pure Xcode project. SwiftPM `Packages/` is gitignored.

```bash
# Build (CLI)
xcodebuild -project Battrix.xcodeproj -scheme Battrix -configuration Debug build

# Run: open in Xcode and ⌘R (easiest — IOKit reads need a real run)
open Battrix.xcodeproj

# All tests
xcodebuild test -project Battrix.xcodeproj -scheme Battrix -destination 'platform=macOS'

# Single test
xcodebuild test -project Battrix.xcodeproj -scheme Battrix -destination 'platform=macOS' -only-testing:BattrixTests/BattrixTests/<testName>
```

Targets: `Battrix` (app), `BattrixTests` (unit, Swift Testing), `BattrixUITests` (XCUITest). Deployment target macOS 15.5, Swift 5.0, app-sandboxed.

## Architecture

- **Data source is IOKit, not the OS battery API.** Battery facts come from the `AppleSmartBattery` IOService via `IORegistryEntryCreateCFProperties`, read as a `[String: Any]` property dictionary. Keys are Apple-private and vendor-specific (e.g. `AppleRawCurrentCapacity`, `AppleRawMaxCapacity`, `DesignCapacity`, `CycleCount`, `Temperature` (centi-°C), `Voltage` (mV), `InstantAmperage`/`Amperage` (mA, signed = charge/discharge), `AdapterDetails` dict, `BatteryData.LifetimeData`, `ManufacturerData` (length-prefixed ASCII blob)). Always read defensively with `as?` and multiple key fallbacks — keys differ across Mac models and silicon.
- **Derived metrics:** health = `AppleRawMaxCapacity / DesignCapacity`; charge% = `AppleRawCurrentCapacity / AppleRawMaxCapacity`; power(W) = `Voltage * Amperage / 1e6`.
- **Sandbox constraint:** `Battrix.entitlements` enables app-sandbox. IOKit `AppleSmartBattery` reads work sandboxed; reading connected-iPhone battery over USB (libimobiledevice / MobileDevice) generally does **not** under sandbox — that feature requires loosening entitlements or a helper. Check this before planning iOS-device support.
- **Persistence.swift / Core Data** is stock Xcode-template boilerplate (`Item` entity) and is currently unused by the UI. Don't assume it's load-bearing; remove or repurpose intentionally.

## Conventions

- Battery values are modeled as a flat `[BatteryInfo]` (label/value strings) and the UI filters by hard-coded label strings (e.g. `"Charge %"`, `"Adapter Wattage"`). This string-keyed coupling is fragile — prefer a typed model when refactoring.
- `print()` debug dumps of the full property dict exist in `getBatteryStats()`; strip before shipping.

## Distribution

Ships as a notarized `.dmg` via GitHub Releases (see `readme.MD`). App icon assets in `Battrix/Assets.xcassets`; screenshots in `Assets/`.
