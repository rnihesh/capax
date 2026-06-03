---
title: "feat: Battrix — surpass coconutBattery Pro (Mac + iOS battery, history, menu bar)"
type: feat
status: active
date: 2026-06-03
origin: docs/brainstorms/2026-06-03-battrix-coconut-parity-requirements.md
---

# feat: Battrix — surpass coconutBattery Pro

## Overview

Rebuild Battrix from a single-file IOKit dump into a premium, menu-bar-native macOS battery monitor that matches coconutBattery 4 **Plus** for free and adds connected **iPhone/iPad** battery reading, **local history graphs**, and a **menu-bar extra**. Read-only monitor (no charge control). Fully offline, no account, no telemetry. Design bar: "did Apple ship this?" — no AI slop.

## Problem Frame

Current `Battrix/ContentView.swift` (640 lines) reads `AppleSmartBattery` via IOKit and renders a flat string-keyed `[BatteryInfo]` list with debug `print()` dumps and unused Core Data boilerplate. It works but is undifferentiated and unmaintainable. The origin requirements doc (`docs/brainstorms/2026-06-03-battrix-coconut-parity-requirements.md`) calls for Plus-tier parity for free with a cleaner, menu-bar-first UX.

## Requirements Trace

- R1. Show everything coconutBattery shows for a Mac (health %, capacity mAh, design capacity, cycles, temp, voltage, amperage, power W, adapter, manufacture date/age).
- R2. Read a connected iPhone/iPad battery health, cycle count, capacity, charge, temp over **USB**; WiFi as fast-follow on same path.
- R3. Persist samples locally and render **trend graphs** (health/capacity/cycles/temperature).
- R4. **Menu-bar extra** with live %, charging glyph, watts + popover; full window for detail.
- R5. UI reads as genuinely premium/native (one hero metric, custom gauge, Swift Charts, material backgrounds, honest labels).
- R6. Repo is exemplary: typed model, no debug prints, no dead Core Data, tests on pure logic, polished README + screenshots, releasable.
- R7. Honesty guardrail: never fake/repair health — true values only.

## Scope Boundaries

- No charge limiting / SMC writes / any battery control (read-only monitor). (see origin: non-goals)
- No cloud sync, accounts, or telemetry — fully offline.
- No Windows/Linux, no iOS companion app.

### Deferred to Separate Tasks

- **WiFi iOS reading**: same usbmuxd network path, enabled after USB path proven — fast-follow, not v1-blocking.
- **iCloud/CloudKit history sync**: research surfaced it as a differentiator; intentionally deferred to keep v1 offline-simple.
- **Energy-hungry app tracking / power-flow Sankey**: future differentiators, not v1.

## Context & Research

### Relevant Code and Patterns

- `Battrix/ContentView.swift` — current IOKit read logic in `getBatteryStats()`; the key-fallback reading patterns (`AppleRawCurrentCapacity` → `AbsoluteCapacity` → `CurrentCapacity`) are correct and should be **preserved into the new typed service**, not rewritten blind.
- `Battrix/Persistence.swift` + `Battrix/Battrix.xcdatamodeld` — stock Core Data `Item` boilerplate, unused → remove, replace with SwiftData for history.
- `Battrix/Battrix.entitlements` — app-sandbox enabled; must be removed/loosened for Process-based iOS tooling + USB.
- `Battrix/BattrixApp.swift` — `WindowGroup` only; add `MenuBarExtra`.

### External References (from research, 2026-06-03)

- iOS read path: `libimobiledevice` → `usbmuxd` → `lockdownd` → `diagnostics_relay_query_ioregistry_entry("AppleSmartBattery")`. CLI equivalent: `idevicediagnostics ioregentry AppleSmartBattery`. Fallback entry `AppleARMPMUCharger` for iPhone 7 and older. Health = `AppleRawMaxCapacity / DesignCapacity`. Device must be **trust-paired**. No first-party Apple API; no Swift package.
- Premium-UI tells: one hero metric large+legible, custom-drawn battery gauge (not stock `Gauge`), Swift Charts with restrained styling, menu-bar-native popover, `.regularMaterial`/vibrancy, semantic colors only for health state, honest technical labels.
- coconut weakness = window-first → Battrix wins by menu-bar-first.

## Key Technical Decisions

- **Typed domain model** replaces string-keyed `[BatteryInfo]`. `MacBattery`, `AdapterInfo`, `IOSDeviceBattery`, `HistorySample` structs. Eliminates fragile label-string filtering in views.
- **Process-based iOS reader, not C linkage.** Implement `IOSDeviceReader` by invoking `libimobiledevice` CLI tools (`idevice_id`, `ideviceinfo`, `idevicediagnostics`) via `Foundation.Process` and parsing their plist/XML output. Rationale: avoids vendoring/linking C libs (libplist/libusbmuxd/openssl) and building autotools in-tree; parsing logic is pure and unit-testable against captured fixtures; distribution bundles the prebuilt binaries in `Battrix.app/Contents/Resources/`. In dev, falls back to Homebrew-installed tools on `PATH`. Trade-off: requires bundling binaries for release (notarization step) — acceptable, documented in rollout notes.
- **Drop the app sandbox.** Required for spawning helper tools + USB device access. Battrix already ships as a notarized DMG (not Mac App Store), so this matches its distribution model. Keep hardened runtime for notarization.
- **SwiftData for history** (macOS 15.5 target supports it) replaces Core Data boilerplate. One `@Model HistorySample`.
- **`@Observable` view model** (Observation framework) over scattered `@State`. Single `BatteryViewModel` owns refresh timer, current readings, and history access.
- **MenuBarExtra (.window style)** for the menu-bar popover; `WindowGroup` for the detail window. Both share the view model via environment.
- **Custom battery gauge** drawn with SwiftUI `Shape`/`Canvas`, animated fill — the visual signature.

## Open Questions

### Resolved During Planning

- iOS read mechanism: diagnostics_relay IORegistry `AppleSmartBattery` (+ `AppleARMPMUCharger` fallback), Process-invoked CLI. (resolved via research)
- Persistence: SwiftData, not Core Data. (resolved)
- Sandbox: drop it; DMG distribution + hardened runtime. (resolved)

### Deferred to Implementation

- Exact `idevicediagnostics` output schema variance across iOS versions — handle defensively; capture real fixtures during execution from any available device.
- Whether `MenuBarExtra(.window)` popover sizing needs a fixed frame vs intrinsic — settle when rendering.
- Final binary-bundling/notarization choreography (which dylibs `idevice*` need) — execution-time, documented as rollout note, not v1-app-logic blocker.

## Output Structure

    Battrix/
      App/
        BattrixApp.swift            # @main: WindowGroup + MenuBarExtra
      Models/
        MacBattery.swift            # typed Mac battery snapshot + derived metrics
        AdapterInfo.swift           # power adapter
        IOSDeviceBattery.swift      # connected iOS device battery
        DeviceConnection.swift      # connection/pairing states enum
        HistorySample.swift         # @Model SwiftData record
      Services/
        MacBatteryService.swift     # IOKit AppleSmartBattery → MacBattery
        IOSDeviceReader.swift       # protocol
        LibimobiledeviceReader.swift# Process + plist parse impl
        IOSDeviceMonitor.swift      # poll/watch connected devices
        HistoryStore.swift          # SwiftData container + sampling
        Formatting.swift            # number/unit/date formatters
      ViewModels/
        BatteryViewModel.swift      # @Observable orchestrator
      Views/
        ContentView.swift           # main window shell (tabs: Summary / History)
        SummaryView.swift
        HeroGaugeView.swift         # custom animated battery gauge
        MacBatterySection.swift
        AdapterSection.swift
        IOSDeviceSection.swift
        HistoryView.swift           # Swift Charts
        MenuBarView.swift           # popover content
        Components/
          MetricRow.swift
          SectionCard.swift
      Resources/
        idevice/                    # bundled CLI binaries (release) — added at packaging
      Assets.xcassets
      Battrix.entitlements          # hardened runtime, no sandbox

## High-Level Technical Design

> *Directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

Data flow:

    IOKit AppleSmartBattery ──▶ MacBatteryService ──▶ MacBattery ┐
                                                                  ├─▶ BatteryViewModel(@Observable) ──▶ Views (Window + MenuBar)
    idevice* CLI (Process) ──▶ LibimobiledeviceReader ─▶ IOSDeviceBattery ┘            │
                                                                                        └─▶ HistoryStore(SwiftData) ─▶ Swift Charts

Refresh loop: `BatteryViewModel` runs a timer (≈5s for live readings); on each tick it pulls `MacBatteryService.read()`, asks `IOSDeviceMonitor` for connected devices, and appends a `HistorySample` at a coarser cadence (e.g. every few minutes / on meaningful delta).

iOS reader states (`DeviceConnection`): `.none` → `.detectedUntrusted` (needs Trust) → `.connected(IOSDeviceBattery)` → `.toolingMissing` (idevice binaries absent). UI renders an explicit, honest panel per state.

## Implementation Units

Phased. Phase 1 = foundation + Mac excellence (ships standalone). Phase 2 = iOS devices. Phase 3 = history + menu bar + repo polish.

### Phase 1 — Foundation & Mac battery

- [x] **Unit 1: Project hygiene & structure**

**Goal:** Clean slate — remove dead code/sandbox, organize files, no debug noise.

**Requirements:** R6

**Dependencies:** None

**Files:**
- Delete: `Battrix/Persistence.swift`, `Battrix/Battrix.xcdatamodeld/`
- Modify: `Battrix/Battrix.entitlements` (remove `app-sandbox` + `files.user-selected.read-only`; keep hardened-runtime-compatible), `Battrix.xcodeproj/project.pbxproj` (drop Core Data refs, sandbox), `Battrix/BattrixApp.swift` (remove `MiniBatteryApp` legacy name → `BattrixApp`, drop Persistence injection)
- Create: source group folders per Output Structure

**Approach:** Strip Core Data + sandbox first so later units build clean. Rename the `@main` struct from `MiniBatteryApp` to `BattrixApp`. Remove all `print()` debug dumps when `getBatteryStats()` logic migrates (Unit 2).

**Patterns to follow:** Keep `FileSystemSynchronizedRootGroup` project style already in `project.pbxproj` — adding folders under `Battrix/` auto-syncs, minimizing pbxproj churn.

**Test scenarios:** Test expectation: none — structural/config only. Verification is a clean build.

**Verification:** `xcodebuild ... build` succeeds with no Core Data, no sandbox entitlement, no `print()` in shipped code.

- [x] **Unit 2: Typed Mac battery model + service**

**Goal:** Port `getBatteryStats()` into a typed `MacBatteryService` returning `MacBattery` + `AdapterInfo`, preserving every existing key-fallback.

**Requirements:** R1, R6, R7

**Dependencies:** Unit 1

**Files:**
- Create: `Battrix/Models/MacBattery.swift`, `Battrix/Models/AdapterInfo.swift`, `Battrix/Services/MacBatteryService.swift`, `Battrix/Services/Formatting.swift`
- Test: `BattrixTests/MacBatteryMathTests.swift`

**Approach:** `MacBattery` holds raw values (chargePercent, healthPercent, currentCapacity, maxCapacity, designCapacity, cycleCount, temperatureC, voltageV, amperageMA, powerW, isCharging, fullyCharged, manufactureDate?, serial?). Derived metrics as computed properties so the math is pure and testable: `health = rawMax/design`, `charge = rawCurrent/rawMax`, `power = voltage*amperage/1e6`. `MacBatteryService.read()` does the IOKit `AppleSmartBattery` property-dict read (port existing fallbacks verbatim), maps into the struct. Keep `AdapterDetails` parsing. Strip the `print()` dumps. Decode `ManufacturerData` length-prefixed ASCII into manufacture info defensively.

**Patterns to follow:** Existing fallback ladders in `ContentView.getBatteryStats()` (lines ~418-619) — preserve the exact key precedence; they encode real cross-model quirks.

**Test scenarios:**
- Happy path: given a fixture property dict (rawMax=4000, design=5000) → `healthPercent == 80.0`.
- Happy path: rawCurrent=3000, rawMax=4000 → `chargePercent == 75.0`.
- Happy path: voltage=12000 mV, amperage=-2000 mA → `powerW ≈ -24.0`.
- Edge case: design=0 or rawMax=0 → derived health/charge return nil (no divide-by-zero), not crash/Inf.
- Edge case: missing optional keys (no serial, no adapter) → struct fields nil, no crash.
- Edge case: temperature centi-°C (3012) → 30.12°C and correct °F.

**Verification:** Unit tests green; service returns a populated `MacBattery` on a real Mac run; no `print` output.

- [x] **Unit 3: View model + refresh orchestration**

**Goal:** `@Observable BatteryViewModel` owning current readings + a refresh timer feeding the UI.

**Requirements:** R1, R4

**Dependencies:** Unit 2

**Files:**
- Create: `Battrix/ViewModels/BatteryViewModel.swift`
- Test: `BattrixTests/BatteryViewModelTests.swift`

**Approach:** `@Observable` class holds `mac: MacBattery?`, `adapter: AdapterInfo?`, `iosDevices`, `connectionState`. `start()` schedules a ~5s timer + an initial read; `refresh()` for manual. Inject services via initializer so tests pass a stub `MacBatteryService`. Keep timer lifecycle tied to scene/window.

**Patterns to follow:** Replace the ad-hoc `Timer`/`@State` in `ContentView`.

**Test scenarios:**
- Happy path: `refresh()` with a stub service updates `mac` to the stubbed value.
- Edge case: service returning nil leaves view model in a safe empty state (UI shows "no battery").
- Integration: starting then stopping invalidates the timer (no leak / no post-stop updates).

**Verification:** Tests green; manual refresh updates UI; timer stops on window close.

- [x] **Unit 4: Redesigned main window UI (Mac)**

**Goal:** Premium Summary view — hero gauge + sectioned cards. Replace the entire current `ContentView` body.

**Requirements:** R1, R5

**Dependencies:** Unit 3

**Files:**
- Create: `Battrix/Views/ContentView.swift` (shell w/ Summary|History tabs), `Battrix/Views/SummaryView.swift`, `Battrix/Views/HeroGaugeView.swift`, `Battrix/Views/MacBatterySection.swift`, `Battrix/Views/AdapterSection.swift`, `Battrix/Views/Components/MetricRow.swift`, `Battrix/Views/Components/SectionCard.swift`

**Approach:** One hero metric (battery health % with capacity comparison) in a custom animated gauge (`Canvas`/`Shape`). Secondary metrics in aligned `MetricRow`s grouped in `SectionCard`s with `.regularMaterial` backgrounds, hairline dividers, SF Symbols, semantic color only for health state (green/yellow/red). Honest labels: "Full Charge Capacity", "Design Capacity", "Cycle Count". Restrained motion (animate gauge fill + value transitions). No gradients-everywhere, no emoji.

**Patterns to follow:** Research premium-UI tells; macOS HIG. Reuse `Formatting.swift`.

**Test scenarios:** Test expectation: none — SwiftUI layout (no business logic). Visual verification only. (Gauge math lives in Unit 2/HeroGaugeView and is covered by Unit 2 derived-metric tests.)

**Verification:** Window renders hero gauge + sections on a real run; light/dark both clean; matches design bar in a screenshot review.

### Phase 2 — iOS device battery

- [x] **Unit 5: iOS device model + reader protocol + libimobiledevice impl**

**Goal:** Read a connected iPhone/iPad battery over USB via Process-invoked `idevice*` tools.

**Requirements:** R2, R7

**Dependencies:** Unit 3

**Files:**
- Create: `Battrix/Models/IOSDeviceBattery.swift`, `Battrix/Models/DeviceConnection.swift`, `Battrix/Services/IOSDeviceReader.swift` (protocol), `Battrix/Services/LibimobiledeviceReader.swift`, `Battrix/Services/IOSDeviceMonitor.swift`
- Test: `BattrixTests/IOSBatteryParsingTests.swift`
- Test fixtures: `BattrixTests/Fixtures/ioreg_applesmartbattery.xml`, `BattrixTests/Fixtures/ideviceinfo.xml`

**Approach:** `IOSDeviceReader` protocol: `listDevices()`, `read(udid:) -> IOSDeviceBattery`. `LibimobiledeviceReader` resolves tool paths (bundled `Contents/Resources/idevice/` first, then `PATH`), runs `idevice_id -l`, `ideviceinfo -u <udid>` (name/model/iOS/serial), and `idevicediagnostics -u <udid> ioregentry AppleSmartBattery` (battery keys); falls back to `AppleARMPMUCharger` entry if the first is empty (iPhone 7 & older). Parse the plist/XML output with `PropertyListSerialization`. Compute health = `AppleRawMaxCapacity/DesignCapacity`. Map errors to `DeviceConnection` states (`.toolingMissing`, `.detectedUntrusted`, `.connected`). **Parsing is the unit-tested seam** (fixtures), Process invocation is thin.

**Execution note:** Capture real `idevicediagnostics ioregentry` output as a fixture if any iOS device is available during execution; otherwise hand-author a representative fixture from the documented key set.

**Patterns to follow:** Mirror `MacBatteryService` defensive `as?` key reads; same health math as `MacBattery`.

**Test scenarios:**
- Happy path: parse `ioreg_applesmartbattery.xml` fixture → correct health %, cycle count, design/full capacity, charge %.
- Happy path: parse `ideviceinfo.xml` → device name/model/iOS version/serial.
- Edge case: `AppleSmartBattery` entry empty → falls back to `AppleARMPMUCharger`, still parses.
- Error path: `idevice_id` not found on PATH and not bundled → reader reports `.toolingMissing`, no crash.
- Error path: device present but pairing/trust error in tool output → `.detectedUntrusted`.
- Edge case: malformed/partial plist → returns nil/error, never crashes.

**Verification:** Parsing tests green against fixtures; with tools installed + a trusted device on a real Mac, a real iPhone's health/cycles display.

- [x] **Unit 6: iOS device UI panel + connection states**

**Goal:** Honest, polished iOS device section in the window + device cards.

**Requirements:** R2, R5

**Dependencies:** Unit 4, Unit 5

**Files:**
- Create: `Battrix/Views/IOSDeviceSection.swift`
- Modify: `Battrix/Views/SummaryView.swift` (host the section), `Battrix/ViewModels/BatteryViewModel.swift` (poll `IOSDeviceMonitor`)

**Approach:** Render per-state: no device (subtle empty hint), tooling missing (one-line install guidance), detected-untrusted ("Unlock device and tap Trust"), connected (device card: name/model/iOS + battery health hero, cycles, capacity, charge, temp — same visual language as the Mac section). Side-by-side Mac + device when present.

**Test scenarios:** Test expectation: none — view layer; state logic covered in Unit 5 + Unit 3. Visual verification only.

**Verification:** Each `DeviceConnection` state renders a correct, honest panel (drive via stub reader); connected device card mirrors Mac visual language.

### Phase 3 — History, menu bar, polish

- [x] **Unit 7: History persistence + Swift Charts trends**

**Goal:** Local sampling + trend graphs (health/capacity/cycles/temperature).

**Requirements:** R3, R5

**Dependencies:** Unit 3 (Unit 5 optional for device history)

**Files:**
- Create: `Battrix/Models/HistorySample.swift` (`@Model`), `Battrix/Services/HistoryStore.swift`, `Battrix/Views/HistoryView.swift`
- Modify: `Battrix/App/BattrixApp.swift` (SwiftData `modelContainer`), `Battrix/ViewModels/BatteryViewModel.swift` (append samples)
- Test: `BattrixTests/HistoryStoreTests.swift`

**Approach:** `HistorySample` stores timestamp + key metrics (health, maxCapacity, cycleCount, temperature, source = mac/device-udid). `HistoryStore` appends on a coarse cadence (every few min or on meaningful delta) to avoid bloat; provides windowed queries (24h/7d/30d/all). `HistoryView` renders restrained Swift Charts line charts with axis labels + scrub readout. Use an in-memory `ModelContainer` for tests.

**Test scenarios:**
- Happy path: appending samples then querying a window returns them ordered by time.
- Edge case: dedup/throttle — two reads within the min interval with no meaningful delta produce a single stored sample (or per chosen policy) — assert the policy.
- Edge case: empty store → chart view shows an empty state, no crash.
- Integration: a view-model refresh that crosses the sampling cadence persists exactly one new `HistorySample`.

**Verification:** Tests green; charts render real trend lines after the app accumulates samples.

- [x] **Unit 8: Menu-bar extra + popover**

**Goal:** Menu-bar-native live status + popover summary.

**Requirements:** R4, R5

**Dependencies:** Unit 3 (Unit 7 for tiny sparkline optional)

**Files:**
- Create: `Battrix/Views/MenuBarView.swift`
- Modify: `Battrix/App/BattrixApp.swift` (add `MenuBarExtra`)

**Approach:** `MenuBarExtra` label shows live % + charging glyph (+ watts when plugged). `.window` style popover shows a compact summary (gauge mini, key metrics, connected device if any) + "Open Battrix" button + quit. Share the one `BatteryViewModel` via environment so window + menu bar stay in sync.

**Test scenarios:** Test expectation: none — SwiftUI scene wiring; underlying data covered by Unit 3/7. Visual verification only.

**Verification:** Menu-bar item shows live %/watts; popover renders + opens window; both reflect the same readings.

- [x] **Unit 9: Repo polish & release readiness**

**Goal:** Make the repo exemplary and the app releasable.

**Requirements:** R6

**Dependencies:** Units 1-8

**Files:**
- Modify: `readme.MD` (rewrite: new feature set, iOS support, history, menu bar, screenshots, install/notarize, libimobiledevice tooling note), `CLAUDE.md` (reflect new architecture), `Assets/` (fresh light/dark screenshots)
- Create: `docs/` notes for distribution (bundling `idevice*` + notarization/hardened-runtime steps), brief `CONTRIBUTING` if warranted
- Verify: app icon present in `Battrix/Assets.xcassets/AppIcon.appiconset`

**Approach:** README reflects reality (no overclaiming — mark WiFi iOS as roadmap). Document the iOS tooling requirement honestly (bundled in release; `brew install libimobiledevice` for source builds). Update CLAUDE.md architecture section. Capture new screenshots from a real run.

**Test scenarios:** Test expectation: none — docs/assets. Verification is review + a clean build/test run.

**Verification:** README matches shipped features; `xcodebuild build` + `xcodebuild test` both green; screenshots current.

## System-Wide Impact

- **Interaction graph:** `BatteryViewModel` is the hub — window views, menu-bar views, and `HistoryStore` all read from it. A change to the model shape ripples to all three; keep it the single source of truth.
- **Error propagation:** iOS reader failures must surface as explicit `DeviceConnection` states, never silent empties or crashes. Mac read failure → "no battery" empty state.
- **State lifecycle risks:** refresh timer must stop on window/scene teardown (no leak, no post-stop writes); history sampling must throttle to avoid DB bloat.
- **API surface parity:** Mac battery and iOS device battery share the same health math and visual language — keep them consistent (one `MetricRow`/`SectionCard`/gauge vocabulary).
- **Integration coverage:** view-model→history sampling cadence is the main cross-layer behavior to integration-test (Unit 7).
- **Unchanged invariants:** IOKit `AppleSmartBattery` read semantics and key fallbacks are preserved verbatim from the working `getBatteryStats()` — the refactor must not change which keys are read or their precedence.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Dropping sandbox affects notarization/trust | Keep hardened runtime; ship notarized DMG (already the distribution model); document in Unit 9 |
| libimobiledevice tools absent at runtime | Graceful `.toolingMissing` state + bundled binaries in release; never crash |
| iOS `idevicediagnostics` output varies by iOS version | Parse defensively, fixture-test, `AppleARMPMUCharger` fallback; mark WiFi/edge variance deferred |
| Can't verify GUI/real-device behavior in CI/session | Unit-test all pure logic (math, parsing) against fixtures; explicitly hand GUI + real-device verification to a real Mac run (honest verification boundary) |
| Bundling/notarizing `idevice*` dylibs is fiddly | Treated as execution/rollout-time; documented, not v1-app-logic blocker; USB feature degrades gracefully if unbundled |
| SwiftData history bloat | Throttle sampling by interval + meaningful delta; windowed queries |

## Documentation / Operational Notes

- Rollout: removing sandbox → re-notarize; bundle `idevice_id`, `ideviceinfo`, `idevicediagnostics` (+ their dylibs) under `Contents/Resources/idevice/`, codesign each, staple. Document the exact dylib set during execution (deferred).
- README must not overclaim: WiFi iOS + iCloud sync are roadmap, not shipped.
- Privacy posture unchanged: fully offline, no telemetry — keep the README privacy section.

## Sources & References

- **Origin document:** docs/brainstorms/2026-06-03-battrix-coconut-parity-requirements.md
- Current code: `Battrix/ContentView.swift` (`getBatteryStats()`), `Battrix/Persistence.swift`, `Battrix/Battrix.entitlements`
- External: libimobiledevice `diagnostics_relay.h` / `idevicediagnostics.c`; coconut-flavour.com; mac-stats.com (Stats); FIPLAB Battery Health 3; Dalton Durst "iOS battery over USB"; jkcoxson/idevice (Rust alt).
