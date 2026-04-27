#!/usr/bin/env bash
# Build ShellHopper.app from source.
# Usage: ./build.sh
# Output: ./build/ShellHopper.app  (drag to /Applications)

set -euo pipefail

APP_NAME="ShellHopper"
BUNDLE_ID="com.shellhopper.app"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

# --- Pre-flight ---------------------------------------------------------------

if ! command -v swift >/dev/null; then
    echo "Error: 'swift' command not found. Install Xcode or Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

echo "==> Building ${APP_NAME} (release)…"
swift build -c release --arch arm64 --arch x86_64 2>/dev/null \
    || swift build -c release   # fall back to host arch on older toolchains

BIN_PATH="$(swift build -c release --show-bin-path)"
EXECUTABLE="${BIN_PATH}/${APP_NAME}"

if [[ ! -x "${EXECUTABLE}" ]]; then
    echo "Error: built executable not found at ${EXECUTABLE}"
    exit 1
fi

# --- Assemble .app bundle -----------------------------------------------------

echo "==> Assembling ${APP_BUNDLE}…"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${EXECUTABLE}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# --- App icon -----------------------------------------------------------------
# Prefer an existing AppIcon.icns; otherwise generate one on the fly from
# Resources/AppIcon.png (a single 1024x1024 PNG is enough — sips downscales).

ICNS_SRC=""
if [[ -f "Resources/AppIcon.icns" ]]; then
    ICNS_SRC="Resources/AppIcon.icns"
elif [[ -f "Resources/AppIcon.png" ]]; then
    echo "==> Generating AppIcon.icns from Resources/AppIcon.png…"
    ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "${ICONSET_DIR}"
    for size in 16 32 64 128 256 512 1024; do
        sips -z "${size}" "${size}" "Resources/AppIcon.png" \
             --out "${ICONSET_DIR}/icon_${size}x${size}.png" >/dev/null
    done
    # Provide the @2x retina variants by aliasing the next-size-up files.
    cp "${ICONSET_DIR}/icon_32x32.png"     "${ICONSET_DIR}/icon_16x16@2x.png"
    cp "${ICONSET_DIR}/icon_64x64.png"     "${ICONSET_DIR}/icon_32x32@2x.png"
    cp "${ICONSET_DIR}/icon_256x256.png"   "${ICONSET_DIR}/icon_128x128@2x.png"
    cp "${ICONSET_DIR}/icon_512x512.png"   "${ICONSET_DIR}/icon_256x256@2x.png"
    cp "${ICONSET_DIR}/icon_1024x1024.png" "${ICONSET_DIR}/icon_512x512@2x.png"
    rm "${ICONSET_DIR}/icon_64x64.png" "${ICONSET_DIR}/icon_1024x1024.png"
    iconutil -c icns "${ICONSET_DIR}" -o "${BUILD_DIR}/AppIcon.icns"
    ICNS_SRC="${BUILD_DIR}/AppIcon.icns"
fi

if [[ -n "${ICNS_SRC}" ]]; then
    cp "${ICNS_SRC}" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" \
        "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || true
fi

# --- Ad-hoc sign --------------------------------------------------------------
# Required so macOS will let the app run without quarantine errors. This is
# *not* a developer-signed build; users who download it from the internet
# will still need to right-click → Open the first time.

echo "==> Ad-hoc signing…"
codesign --force --deep --sign - "${APP_BUNDLE}"

# --- Done ---------------------------------------------------------------------

echo
echo "✅ Built ${APP_BUNDLE}"
echo
echo "Next steps:"
echo "  1. Drag ${APP_BUNDLE} to /Applications"
echo "  2. Launch it (right-click → Open the first time, since it's unsigned)"
echo "  3. Open the menu-bar icon → Settings… to set hotkeys"
echo "  4. The first time a hotkey runs, macOS will prompt to allow ShellHopper"
echo "     to control Terminal. Click Allow."
echo
