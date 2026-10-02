#!/usr/bin/env bash
#
# package-macos.sh — turn the official RAPTOR Avalonia distribution into RAPTOR.app
#
# RAPTOR is a Windows program published as a plain folder of .NET assemblies.
# This script wraps that folder into a proper macOS application bundle so it can
# be launched from Finder / Dock instead of a terminal.
#
# Usage:
#   ./tools/package-macos.sh <path-to-publish-folder> [options]
#
# Options:
#   -o, --out DIR        Where to write RAPTOR.app        (default: ./build)
#   -z, --zip            Also produce a Release-ready .zip
#   -d, --dmg            Also produce a distributable .dmg
#   --no-trim            Keep Windows/Linux runtimes and .pdb symbols
#   -h, --help           Show this help
#
# Requirements: macOS, Xcode command line tools (clang, swiftc, iconutil),
#               and the .NET 8 SDK or runtime installed for testing.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OUT_DIR="$REPO_ROOT/build"
MAKE_ZIP=0
MAKE_DMG=0
TRIM=1
PUBLISH_DIR=""

die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[1;32m ok\033[0m %s\n' "$*"; }

usage() { sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0; }

# ---------------------------------------------------------------- arguments --
while [ $# -gt 0 ]; do
    case "$1" in
        -o|--out)   OUT_DIR="${2:?--out needs a value}"; shift 2 ;;
        -z|--zip)   MAKE_ZIP=1; shift ;;
        -d|--dmg)   MAKE_DMG=1; shift ;;
        --no-trim)  TRIM=0; shift ;;
        -h|--help)  usage ;;
        -*)         die "unknown option: $1" ;;
        *)          [ -z "$PUBLISH_DIR" ] || die "more than one publish folder given"
                    PUBLISH_DIR="$1"; shift ;;
    esac
done

[ -n "$PUBLISH_DIR" ] || { printf 'error: no publish folder given\n\n' >&2; usage; }
[ -d "$PUBLISH_DIR" ] || die "not a directory: $PUBLISH_DIR"
PUBLISH_DIR="$(cd "$PUBLISH_DIR" && pwd)"

# ------------------------------------------------------------------- checks --
[ "$(uname -s)" = "Darwin" ] || die "this script only builds macOS bundles"

for tool in clang swiftc iconutil rsync ditto plutil hdiutil; do
    command -v "$tool" >/dev/null 2>&1 || die "missing required tool: $tool"
done

[ -f "$PUBLISH_DIR/raptor.dll" ] || \
    die "$PUBLISH_DIR does not look like the RAPTOR distribution (raptor.dll not found)"

# Read the version from the repo, falling back to a sane default.
VERSION="$(cat "$REPO_ROOT/VERSION" 2>/dev/null || echo "0.0.0")"
VERSION="${VERSION%%-*}"   # strip any pre-release suffix for CFBundleVersion

# ------------------------------------------------------------------ staging --
APP="$OUT_DIR/RAPTOR.app"
info "packaging RAPTOR $VERSION"
info "source : $PUBLISH_DIR"
info "target : $APP"

rm -rf "$APP"
mkdir -p "$OUT_DIR" "$APP/Contents/MacOS" "$APP/Contents/Resources"

# --------------------------------------------------------- program payload --
# Everything the .NET runtime needs lives in Contents/Resources.
info "copying program files"
rsync -a --exclude '.DS_Store' "$PUBLISH_DIR"/ "$APP/Contents/Resources"/

if [ "$TRIM" -eq 1 ]; then
    # A macOS bundle has no use for the Windows/Linux native libraries that the
    # upstream build ships for other platforms, nor for debug symbols. Dropping
    # them roughly halves the download. --no-trim keeps everything.
    #
    # CAUTION: runtimes/unix must be KEPT. It holds the Unix build of
    # System.Drawing.Common.dll, which .NET resolves for macOS. Deleting it fails
    # at startup with a misleading "Could not load file or assembly
    # 'System.Drawing.Common'" error even though that assembly is present at the
    # payload root.
    info "trimming non-macOS payload"
    rm -rf "$APP/Contents/Resources/runtimes"/win* \
           "$APP/Contents/Resources/runtimes"/linux*
    # Also drop the non-macOS entries inside the osx folder, if any appear.
    find "$APP/Contents/Resources/runtimes/osx" -type f \
        ! -name '*.dylib' -delete 2>/dev/null || true
    rm -f "$APP/Contents/Resources/raptor.exe" \
          "$APP/Contents/Resources"/*.pdb \
          "$APP/Contents/Resources"/*/*.pdb 2>/dev/null || true
fi

# ------------------------------------------------------------- the launcher --
info "compiling launcher"
LAUNCHER_BIN="$(mktemp -t raptor-launcher)"
trap 'rm -f "$LAUNCHER_BIN"' EXIT
clang -O2 -Wall -Wextra -o "$LAUNCHER_BIN" "$SCRIPT_DIR/launcher.c"
install -m 755 "$LAUNCHER_BIN" "$APP/Contents/MacOS/RAPTOR"
ok "launcher built"

# --------------------------------------------------------------------- icon --
info "generating icon"
ICON_WORK="$(mktemp -d -t raptor-icon)"
trap 'rm -f "$LAUNCHER_BIN"; rm -rf "$ICON_WORK"' EXIT

# -module-cache-path keeps Swift from writing into the shared system temp dir,
# which may be unwritable in sandboxed or CI environments.
swiftc -O -module-cache-path "$ICON_WORK/modulecache" \
    -o "$ICON_WORK/icon-gen" "$SCRIPT_DIR/icon-gen.swift"
"$ICON_WORK/icon-gen" "$ICON_WORK/png"

ICONSET="$ICON_WORK/RAPTOR.iconset"
mkdir -p "$ICONSET"
cp "$ICON_WORK/png/icon_16.png"   "$ICONSET/icon_16x16.png"
cp "$ICON_WORK/png/icon_32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICON_WORK/png/icon_32.png"   "$ICONSET/icon_32x32.png"
cp "$ICON_WORK/png/icon_64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICON_WORK/png/icon_128.png"  "$ICONSET/icon_128x128.png"
cp "$ICON_WORK/png/icon_256.png"  "$ICONSET/icon_128x128@2x.png"
cp "$ICON_WORK/png/icon_256.png"  "$ICONSET/icon_256x256.png"
cp "$ICON_WORK/png/icon_512.png"  "$ICONSET/icon_256x256@2x.png"
cp "$ICON_WORK/png/icon_512.png"  "$ICONSET/icon_512x512.png"
cp "$ICON_WORK/png/icon_1024.png" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/RAPTOR.icns"
ok "icon built"

# ---------------------------------------------------------------- Info.plist --
info "writing Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>RAPTOR</string>
    <key>CFBundleDisplayName</key>
    <string>RAPTOR</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.novicesausage.raptor</string>
    <key>CFBundleExecutable</key>
    <string>RAPTOR</string>
    <key>CFBundleIconFile</key>
    <string>RAPTOR.icns</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist" >/dev/null || die "generated Info.plist is invalid"

# Ship the launcher source inside the bundle for reference / rebuilds.
install -m 644 "$SCRIPT_DIR/launcher.c" "$APP/Contents/Resources/launcher.c"

# -------------------------------------------------------------- permissions --
# Normalise modes so the bundle is readable regardless of the source umask.
find "$APP" -type d -exec chmod 755 {} +
find "$APP" -type f -exec chmod 644 {} +
chmod 755 "$APP/Contents/MacOS/RAPTOR"
find "$APP/Contents/Resources" -name '*.dylib' -exec chmod 755 {} + 2>/dev/null || true

# Strip quarantine / provenance attributes so Gatekeeper does not nag a second time.
xattr -cr "$APP" 2>/dev/null || true

# ------------------------------------------------------------- verification --
info "verifying bundle"
plutil -lint "$APP/Contents/Info.plist" >/dev/null && ok "Info.plist valid"
[ -x "$APP/Contents/MacOS/RAPTOR" ] && ok "launcher is executable"
[ -f "$APP/Contents/Resources/RAPTOR.icns" ] && ok "icon present"
[ -f "$APP/Contents/Resources/raptor.dll" ] && ok "raptor.dll present"
[ -f "$APP/Contents/Resources/runtimes/osx/native/libSkiaSharp.dylib" ] && ok "native libs present"

# Register with LaunchServices so the icon and name show up immediately.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$APP" 2>/dev/null || true

# ------------------------------------------------------------------ archive --
if [ "$MAKE_ZIP" -eq 1 ]; then
    ZIP="$OUT_DIR/RAPTOR-${VERSION}-macos-arm64.zip"
    info "creating $ZIP"
    rm -f "$ZIP"
    # ditto preserves the executable bits and symlinks that `zip` would mangle.
    ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
    ok "archive: $ZIP ($(du -h "$ZIP" | cut -f1))"
fi

# -------------------------------------------------------------------- disk --
if [ "$MAKE_DMG" -eq 1 ]; then
    DMG="$OUT_DIR/RAPTOR-${VERSION}-macos-arm64.dmg"
    info "creating $DMG"

    DMG_WORK="$(mktemp -d -t raptor-dmg)"
    trap 'rm -f "$LAUNCHER_BIN"; rm -rf "$ICON_WORK" "$DMG_WORK"' EXIT

    # The .app never carries its runtime cache into a distribution: it holds
    # fontconfig caches regenerated on first launch, and shipping stale ones can
    # break a read-only mounted volume.
    rm -rf "$APP/Contents/cache"

    # Staging folder: the app plus the usual drag target.
    DMG_STAGE="$DMG_WORK/stage"
    mkdir -p "$DMG_STAGE"
    cp -R "$APP" "$DMG_STAGE/RAPTOR.app"
    ln -s /Applications "$DMG_STAGE/Applications"

    # This file is the only place a downloader learns about the runtime
    # requirements, since the DMG has no other documentation surface.
    sed -e "s/@VERSION@/$VERSION/g" > "$DMG_STAGE/READ ME FIRST.txt" <<'README'
RAPTOR for macOS @VERSION@
=================================

INSTALL
  Drag RAPTOR.app into the Applications folder, then open it from there.

REQUIRED (not bundled)
  1. .NET 8.0 Runtime
     https://dotnet.microsoft.com/download/dotnet/8.0
     Choose: macOS -> Arm64 -> Runtime

     Without it RAPTOR shows a dialog and will not start.

  2. libgdiplus (needed for image handling)
         brew install mono-libgdiplus

INSTALLING WITH HOMEBREW
  brew install --cask dotnet-runtime
  brew install mono-libgdiplus

FIRST LAUNCH IS BLOCKED BY GATEKEEPER
  This build is not code-signed, so macOS will warn that it cannot be
  verified. Clear the flag once, then open the app again:

      xattr -dr com.apple.quarantine /Applications/RAPTOR.app

  Or: System Settings -> Privacy & Security -> Open Anyway.
  Or: right-click RAPTOR.app and choose Open.

ABOUT
  RAPTOR is a flowchart-based programming environment, originally developed
  by and for the US Air Force Academy. It is public domain (US Air Force
  policy). This is an unofficial macOS repackaging and is not endorsed by the
  RAPTOR authors.

  RAPTOR homepage: https://raptor.martincarlisle.com/
  Packaged by:     https://github.com/NoviceSausage/RAPTOR-macos
  Full credits:    THIRD-PARTY-NOTICES.md in that repository
README

    # Build the layout, then compress. The staging folder is used so the source
    # .app in build/ is never mutated by the volume step.
    UNCOMPRESSED="$DMG_WORK/RAPTOR-tmp.dmg"
    hdiutil create -quiet -srcfolder "$DMG_STAGE" -volname "RAPTOR" \
        -fs HFS+ -format UDRW -ov "$UNCOMPRESSED" >/dev/null

    # Mount, arrange the Finder window, then unmount so the .DS_Store with the
    # icon positions is baked into the image.
    MOUNT_POINT="/Volumes/RAPTOR"
    [ -d "$MOUNT_POINT" ] && hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    hdiutil attach "$UNCOMPRESSED" -nobrowse -quiet -mountpoint "$MOUNT_POINT"

    if osascript <<'APPLESCRIPT' >/dev/null 2>&1
tell application "Finder"
    tell disk "RAPTOR"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 140, 800, 540}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set position of item "RAPTOR.app" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}
        set position of item "READ ME FIRST.txt" of container window to {300, 380}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
APPLESCRIPT
    then
        ok "Finder layout applied"
    else
        warn "could not arrange the Finder window (needs a GUI session);"
        warn "the DMG is still valid, its icons are just not repositioned"
    fi

    # Detach politely, then forcibly if something still holds the volume.
    sync
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || \
        hdiutil detach "$MOUNT_POINT" -force -quiet 2>/dev/null || \
        warn "could not unmount $MOUNT_POINT; using the image anyway"

    rm -f "$DMG"
    hdiutil convert "$UNCOMPRESSED" -format UDZO -imagekey zlib-level=9 \
        -o "$DMG" >/dev/null

    # A DMG that cannot be verified or mounted is worse than no DMG.
    hdiutil verify "$DMG" >/dev/null || die "generated DMG failed verification"
    ok "disk image verified"
    ok "archive: $DMG ($(du -h "$DMG" | cut -f1))"
fi

printf '\n'
ok "built $APP ($(du -sh "$APP" | cut -f1))"
printf 'Open it with:  open "%s"\n' "$APP"
