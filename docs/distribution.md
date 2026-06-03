# Distribution & Notarization

Battrix ships as a **notarized DMG** (direct download), not through the Mac App Store. This is required because the app is **not sandboxed** — it spawns the libimobiledevice helper tools and reaches USB-connected iOS devices, neither of which the App Store sandbox permits.

## Entitlements

`Battrix/Battrix.entitlements`:
- **No** `com.apple.security.app-sandbox`.
- `com.apple.security.cs.disable-library-validation` — allows the bundled helper tools/dylibs to load under the hardened runtime.
- **Hardened runtime stays ON** (`ENABLE_HARDENED_RUNTIME = YES`) so the build can be notarized.

## Bundling the iOS device tools

For release builds, bundle the libimobiledevice CLI tools so users need no setup:

1. Obtain the tools and their dylibs (e.g. via Homebrew, then collect with `otool -L`):
   - Binaries: `idevice_id`, `ideviceinfo`, `idevicediagnostics`
   - Dylibs they link: `libimobiledevice`, `libimobiledevice-glue`, `libplist`, `libusbmuxd`, `libtatsu`, `libssl`/`libcrypto` (OpenSSL), etc.
2. Place them under `Battrix.app/Contents/Resources/idevice/` (add a Copy Files build phase, or a packaging script).
3. Rewrite the dylib load paths to `@loader_path`/`@executable_path` with `install_name_tool` so they resolve inside the bundle.
4. **Code-sign every binary and dylib** with the Developer ID, then sign the app.

`LibimobiledeviceReader` already looks in `Contents/Resources/idevice/` first, then falls back to `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin` — so source builds work with `brew install libimobiledevice` and release builds work with the bundled copy.

## Notarize & staple

```bash
# Archive / build a Release app, then:
ditto -c -k --keepParent Battrix.app Battrix.zip
xcrun notarytool submit Battrix.zip --keychain-profile "AC_PROFILE" --wait
xcrun stapler staple Battrix.app
# Build the DMG from the stapled app, then staple the DMG too.
```

## Verification boundary

Mac battery logic, plist parsing, and history are unit-tested. **The iPhone/iPad USB path and the GUI must be verified on a real Mac with a trusted device connected** — they can't be exercised in CI. When validating a release, confirm:
- A trusted iPhone/iPad shows correct health & cycle count.
- The `.toolingMissing` / `.detectedUntrusted` states render when tools are absent or the device isn't trusted.
- The menu-bar item and window stay in sync.
