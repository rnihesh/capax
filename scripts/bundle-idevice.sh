#!/usr/bin/env bash
#
# bundle-idevice.sh — copy the libimobiledevice CLI tools and their full dylib closure into a
# built Capax.app so iOS-device reading works with no Homebrew install on the user's Mac.
#
# Walks the dependency tree recursively, copies every non-system dylib into
# Contents/Resources/idevice/, rewrites all load paths to @loader_path, and ad-hoc signs everything
# (open-source build — no paid Apple Developer ID / notarization).
#
# Usage: scripts/bundle-idevice.sh /path/to/Capax.app
#
set -euo pipefail

APP="${1:?usage: bundle-idevice.sh /path/to/Capax.app}"
[ -d "$APP" ] || { echo "error: $APP not found"; exit 1; }

DEST="$APP/Contents/Resources/idevice"
TOOLS=(idevice_id ideviceinfo idevicediagnostics)
BREW_BIN="$(brew --prefix)/bin"

rm -rf "$DEST"; mkdir -p "$DEST"

echo "→ copying tools from $BREW_BIN"
for t in "${TOOLS[@]}"; do
  [ -x "$BREW_BIN/$t" ] || { echo "error: $t not found — run 'brew install libimobiledevice'"; exit 1; }
  cp "$BREW_BIN/$t" "$DEST/$t"; chmod u+w "$DEST/$t"
done

# Recursively copy every non-system dylib a file links against.
collect() {
  local bin="$1"
  while read -r lib; do
    case "$lib" in /usr/lib/*|/System/*|@*) continue ;; esac
    local base; base="$(basename "$lib")"
    if [ ! -f "$DEST/$base" ]; then
      cp "$lib" "$DEST/$base"; chmod u+w "$DEST/$base"
      collect "$DEST/$base"
    fi
  done < <(otool -L "$bin" | tail -n +2 | awk '{print $1}')
}
echo "→ resolving dylib closure"
for t in "${TOOLS[@]}"; do collect "$DEST/$t"; done

# Rewrite install names so everything loads from its own folder.
echo "→ rewriting load paths to @loader_path"
for f in "$DEST"/*; do
  [[ "$f" == *.dylib ]] && install_name_tool -id "@loader_path/$(basename "$f")" "$f"
  while read -r lib; do
    case "$lib" in /usr/lib/*|/System/*|@*) continue ;; esac
    install_name_tool -change "$lib" "@loader_path/$(basename "$lib")" "$f"
  done < <(otool -L "$f" | tail -n +2 | awk '{print $1}')
done

# Ad-hoc sign: dylibs first, then the tools that load them.
echo "→ ad-hoc signing"
for f in "$DEST"/*.dylib; do codesign --force --sign - "$f"; done
for t in "${TOOLS[@]}"; do codesign --force --sign - "$DEST/$t"; done

echo "✓ bundled $(ls "$DEST" | wc -l | tr -d ' ') files into Contents/Resources/idevice/"
echo "  verify (should be all @loader_path / system):"
otool -L "$DEST/idevicediagnostics" | tail -n +2 | sed 's/^/    /'
