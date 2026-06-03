# Distribution (open-source, no paid Apple account)

Battrix ships as an **ad-hoc-signed `.dmg`** — no Mac App Store, no paid Apple Developer ID, no notarization. The app is **not sandboxed** (it spawns the bundled libimobiledevice tools and reaches USB devices). Trust comes from the source being public, not from Apple's signature.

## One command

```bash
brew install libimobiledevice     # one-time: the tools to bundle
scripts/make-release-dmg.sh       # → Battrix.dmg
```

That builds Release, bundles the iOS tools, ad-hoc signs, and makes the DMG.

## What the scripts do

### `scripts/bundle-idevice.sh <Battrix.app>`
Makes iOS-device reading work with **zero setup** on the user's Mac:
1. Copies `idevice_id`, `ideviceinfo`, `idevicediagnostics` from Homebrew into `Battrix.app/Contents/Resources/idevice/`.
2. **Recursively** copies every non-system dylib they link (libimobiledevice, libimobiledevice-glue, libplist, libusbmuxd, libssl, libcrypto — and anything *those* link).
3. Rewrites all load paths to `@loader_path/...` with `install_name_tool` so the tools find their dylibs next to themselves inside the bundle (verify with `otool -L`).
4. Ad-hoc signs every binary and dylib (`codesign --sign -`).

`LibimobiledeviceReader` looks in `Contents/Resources/idevice/` first, then falls back to Homebrew/`PATH` — so bundled release builds and `brew`-based source builds both work.

### `scripts/make-release-dmg.sh`
Release build → `bundle-idevice.sh` → ad-hoc sign the whole app (with `Battrix.entitlements`, whose `disable-library-validation` lets the ad-hoc-signed dylibs load) → `hdiutil` DMG.

## Gatekeeper (because it's unsigned)

Without a paid Developer ID the app isn't notarized, so first launch is blocked by default. Tell users either:
- **Right-click the app → Open** (then confirm) the first time, or
- ```bash
  xattr -dr com.apple.quarantine /Applications/Battrix.app
  ```

## If you later get a paid Apple Developer account
Then you can upgrade to a trusted, double-clickable download:
```bash
codesign --force --deep --options runtime --timestamp \
  --entitlements Battrix/Battrix.entitlements \
  --sign "Developer ID Application: NAME (TEAMID)" Battrix.app
xcrun notarytool submit Battrix.dmg --keychain-profile "AC_PROFILE" --wait
xcrun stapler staple Battrix.dmg
```

## Verification boundary

Mac battery logic, plist parsing, and history are unit-tested. The **iPhone/iPad USB path and the GUI must be verified on a real Mac with a trusted device** — they can't run in CI. Before publishing a DMG, confirm on a fresh/clean Mac (or one without Homebrew):
- `Battrix.app/Contents/Resources/idevice/idevice_id -l` runs (proves the bundled dylibs resolve).
- A trusted iPhone/iPad shows correct health & cycle count.
- The `.toolingMissing` / `.detectedUntrusted` states render correctly.
