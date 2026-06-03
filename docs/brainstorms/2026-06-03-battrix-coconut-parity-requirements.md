# Battrix — Surpass coconutBattery Pro

**Status:** Requirements (brainstorm output)
**Date:** 2026-06-03
**Owner:** Nihesh

## Problem & Goal

Battrix today is a single-window macOS app dumping raw `AppleSmartBattery` IOKit values into a flat list. It works but is undifferentiated. Goal: make Battrix a **best-in-class Mac battery monitor that exceeds coconutBattery Pro** — clean, minimal, native, fast — and adds connected **iPhone/iPad battery reading** (the headline coconutBattery feature) plus **history graphs** and a **menu-bar presence**.

Design north star: *premium, minimal, native macOS — zero AI slop.* Restraint over decoration. Looks like Apple shipped it.

## Users

- Mac owners who care about battery longevity (health %, cycles, capacity fade).
- People checking a Mac's battery before buying/selling (used-Mac market — coconutBattery's classic use).
- iPhone/iPad owners wanting battery health without Apple's buried Settings screen.
- Power users who want live watts/amps/temp in the menu bar.

## Scope (decided)

| Decision | Choice |
|---|---|
| iOS device battery over USB **and WiFi** | **Full support** — read connected iPhone/iPad battery (health, cycles, capacity, serial, temp, charge) over USB; support WiFi/network-paired devices too |
| App form factor | **Window + menu-bar extra** (live glanceable readout + popover; full window for detail) |
| Battery history | **Yes** — persist samples locally, show trend graphs (capacity/health/cycles/temperature over time) |
| Charge limiting (AlDente-style) | **Out of scope** — Battrix stays a read-only monitor (no privileged SMC writes) |

### coconutBattery reference (verified via research, 2026-06-03)
- Current product is **coconutBattery 4**; paid tier is **"Plus"** (formerly "Pro").
- **Free:** Mac battery (health, capacity, cycles, temp, adapter wattage, manufacture date); read iOS device battery over **USB**; save snapshots; basic menu bar.
- **Plus:** iOS devices over **WiFi** (cable-free); Battery Lifetime Analyzer (voltage/temp/rate ranges); Advanced Viewer + SSD stats; richer charts; custom alerts; printing templates; online-account history sync.
- coconut's known weakness: **window-first, not menu-bar-native** — Battrix wins by being menu-bar-first.
- Battrix targets Plus-tier capability **for free**, with a cleaner menu-bar-native UI.

## Feature Set

### Mac battery (core — exists, needs rework)
- Charge %, charging state, time-to-full / time-to-empty.
- Health % (FullCharge/Design), max vs design capacity (mAh), current capacity.
- Cycle count, manufacture date / age, temperature, voltage, amperage, instantaneous power (W).
- Power adapter: wattage, name, manufacturer, voltage, current, serial, connection state.
- Condition/service flags where exposed.

### iOS device panel (new — headline)
- Auto-detect connected iPhone/iPad (USB now, WiFi-paired later in same model).
- Show device name, model, iOS version, serial.
- Battery: design capacity, full-charge capacity, **health %**, cycle count, current charge %, charging state, temperature.
- Graceful states: no device / not paired / trust required / driver missing.

### History & trends (new)
- Periodic local sampling of key Mac metrics (and iOS device when present).
- Trend charts: health %, capacity, cycle count, temperature over time.
- Lightweight, privacy-first: all local, no cloud, no account.

### Menu-bar extra (new)
- Live %, charging glyph, and watts in the menu bar.
- Popover with compact summary + button to open full window.

### Polish
- One-click "copy battery report" (keep, refine).
- Manual refresh + sensible auto-refresh cadence.
- Light/dark native styling, SF Symbols, Swift Charts.

## Success Criteria

1. Shows **everything coconutBattery Pro shows for a Mac**, plus connected-iOS-device battery health — for free.
2. Reads a USB-connected iPhone/iPad's battery health & cycle count reliably; WiFi-paired devices supported.
3. History graphs render real trends from locally persisted samples.
4. Menu-bar extra shows live status without opening the window.
5. UI reads as genuinely premium/native — passes the "did Apple ship this?" bar, no generic AI-dashboard look.
6. Repo is clean and exemplary: typed model (no string-keyed `[BatteryInfo]`), no debug `print` dumps, no dead Core Data boilerplate, documented, tested where it matters, polished README + screenshots, releasable.

## Non-Goals

- Charge limiting / SMC writes / any battery control.
- Cloud sync / online accounts / telemetry (stay fully offline & private).
- Windows/Linux. iOS-app companion (Battrix is the Mac reader).

## Key Risks / Unknowns (resolve in planning via research agent)

- **Sandbox vs iOS-over-USB:** libimobiledevice/usbmuxd USB access likely incompatible with app sandbox → may drop sandbox or add exceptions; affects notarization/distribution. **Confirm exact entitlement path.**
- **iOS battery health/cycles source:** plain `ideviceinfo com.apple.mobile.battery` gives charge but not health/cycles; health/cycles need diagnostics relay / device IORegistry (`AppleSmartBattery` on device). Confirm reliable key set across iOS versions.
- **Dependency strategy:** bundle libimobiledevice (+ libplist, libusbmuxd, openssl) — SwiftPM binary target vs vendored vs Homebrew. Notarization of bundled dylibs.
- **WiFi device reading:** requires prior USB pairing + "connect over network"; usbmuxd network mode. Scope WiFi as fast-follow if it complicates first ship.
- **Trust/pairing UX:** first connection needs device "Trust this computer" + pairing record.

## Resolved decisions (post-research)

- **WiFi iOS reading:** USB-first in v1; WiFi is a fast-follow on the same usbmuxd path (network-paired devices). coconut itself gates WiFi behind Plus, so USB-first base is right.
- **iOS read mechanism:** `diagnostics_relay` → IORegistry `AppleSmartBattery` (fallback `AppleARMPMUCharger`), health computed from raw keys. Bundle a vendored libimobiledevice/idevice toolchain (CLI binaries or linked lib) behind a Swift `IOSDeviceReader` abstraction — exact vendoring strategy decided in planning.
- **Honesty guardrail:** never fake/repair battery health (explicitly avoid 3uTools-style "100% repair"). Report true values only.
