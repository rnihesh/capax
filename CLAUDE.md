# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What Battrix is

Native macOS SwiftUI app that reads battery telemetry from the Mac's hardware **and** from a connected iPhone/iPad over USB, shown in a menu-bar-native UI with local history graphs. Read-only monitor (no charge control). Fully offline. Goal: surpass coconutBattery 4 Plus for free.

## Build / run / test

Pure Xcode project (no SPM/CocoaPods). Xcode 26+, macOS 15.5 deployment target, Swift 5.

```bash
# Build
xcodebuild -project Battrix.xcodeproj -scheme Battrix -configuration Debug -destination 'platform=macOS' build

# Run: open in Xcode and ⌘R (IOKit + device reads need a real run)
open Battrix.xcodeproj

# All tests
xcodebuild test -project Battrix.xcodeproj -scheme Battrix -destination 'platform=macOS'

# A single Swift Testing test
xcodebuild test -project Battrix.xcodeproj -scheme Battrix -destination 'platform=macOS' \
  -only-testing:BattrixTests/MacBatteryMathTests/healthIsFullChargeOverDesign
```

Files under `Battrix/`, `BattrixTests/`, `BattrixUITests/` are auto-synced into their targets via `PBXFileSystemSynchronizedRootGroup` — **just add files in the right folder, no pbxproj editing needed.**

## Architecture

Layered, with one observable view model as the single source of truth:

- **Models/** — typed value types. `MacBattery` and `IOSDeviceBattery` store *raw* hardware values; every user-facing metric (health, charge, power) is a **pure computed property** so the math is testable and honest. Health is always `rawMaxCapacity / designCapacity` — Battrix never fakes/repairs a number. `HistorySample` is the one SwiftData `@Model`.
- **Services/** — `MacBatteryService` reads IOKit `AppleSmartBattery` (preserve the key-fallback ladders — they encode real cross-model quirks). `LibimobiledeviceReader` reads a connected iOS device by shelling out (`Foundation.Process`) to the libimobiledevice CLI tools; **all output parsing lives in the pure `IOSPlistParsing` enum** (the unit-tested seam) while Process invocation stays thin. `HistoryStore` persists throttled samples. `Formatting`/`BatteryReport` are presentation helpers.
- **ViewModels/** — `BatteryViewModel` (`@MainActor @Observable`) owns the refresh timer, current Mac/adapter/iOS readings (`DeviceConnection` enum), and history sampling. Both the window and the menu bar observe this one instance. Services are injected via `MacBatterySource` / `IOSDeviceReader` protocols so tests use stubs.
- **Views/** — `ContentView` (Summary/History tabs) + `MenuBarView`. Shared visual vocabulary in `Views/Components/` (`SectionCard`, `MetricRow`, `Theme`) and `HeroGaugeView` (custom battery gauge). Semantic color only signals battery condition; everything else is restrained/native.

### iOS device reading (the non-obvious part)
- Path: libimobiledevice → usbmuxd → lockdownd → `idevicediagnostics ioregentry AppleSmartBattery` (fallback `AppleARMPMUCharger`). Device must be trust-paired. No first-party Apple API, no Swift package — tools are bundled in `Contents/Resources/idevice/` for releases, or found on `PATH`/Homebrew for source builds.
- States surface honestly via `DeviceConnection`: `.noDevice`, `.toolingMissing`, `.detectedUntrusted`, `.connected`, `.failed`. Never a silent empty.

### Sandbox & distribution
- **App sandbox is intentionally off** (`Battrix.entitlements`) — required to spawn the helper tools and reach USB. Battrix ships as a notarized DMG (hardened runtime stays on), not Mac App Store. See `docs/distribution.md`.

## Testing notes (important)

- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`), not XCTest.
- **SwiftData under Swift Testing is fragile.** Two gotchas, both already handled — keep them when editing tests:
  1. The host app (`BattrixApp`) creates **no** ModelContainer under XCTest (guarded on `XCTestConfigurationFilePath`) — a second container for the same `@Model` in-process traps.
  2. `HistoryStoreTests` uses **one shared `static` in-memory container** cleared before each test, and all suites are `@MainActor` — creating a fresh container per test, or fetching concurrently with other suites, trips a SwiftData SIGTRAP.
- Pure logic (battery math, plist parsing, throttle policy) is the primary test surface. GUI and real-device behavior must be verified on a real Mac run.

## Conventions

- Add new metrics by extending the typed model + a `MetricRow`, not by threading strings through views.
- Keep IOKit/plist reads defensive (`as?`, multiple key fallbacks); different Macs and iOS versions expose different keys.
