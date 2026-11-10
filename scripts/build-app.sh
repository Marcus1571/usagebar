#!/bin/zsh
# Builds build/UsageBar.app and signs it (ad hoc by default: no Apple developer account needed).
# Pass --install to also copy it to ~/Applications (and relaunch it).
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"   sign with your own certificate
#                                                                  (hardened runtime, timestamped)
#   SPARKLE=1                                                      fetch + embed Sparkle, link the updater,
#                                                                  add the SU* keys (distribution builds)
#   BUNDLE_ID=local.usagebar                                       use your own bundle identifier
# The version comes from the latest "## X.Y.Z" heading in CHANGELOG.md; override with VERSION=x.y.z.
# The distribution DMG is made by scripts/make-dmg.sh, which sets SPARKLE and the identity for you.
set -euo pipefail
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
BUNDLE_ID="${BUNDLE_ID:-com.usagebar.app}"
SPARKLE="${SPARKLE:-0}"
cd "${0:A:h:h}"

VERSION="${VERSION:-$(grep -m1 -oE '^## [0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md | sed 's/^## //')}"
# Numeric build stamp Sparkle compares (CFBundleVersion and appcast sparkle:version): 0.6.0 -> 600.
NUMERIC_VERSION="$(echo "$VERSION" | awk -F. '{print $1*10000+$2*100+$3}')"

if [[ "$SPARKLE" == 1 ]]; then
  ./scripts/fetch-sparkle.sh
fi
SPARKLE_FLAGS=()
if [[ "$SPARKLE" == 1 ]]; then
  SPARKLE_FLAGS=(-F .build/sparkle -framework Sparkle)
fi

# Plain swiftc: SwiftPM is broken with some Command Line Tools versions, and this is one module.
# The Sparkle build writes its own binary: it links the framework, so it cannot serve as the
# dependency-free dev binary that `build/UsageBar --selftest` uses.
mkdir -p build
BIN="build/UsageBar"
if [[ "$SPARKLE" == 1 ]]; then BIN="build/UsageBar-dist"; fi
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macosx14.0" Sources/UsageBar/*.swift -o "$BIN" "${SPARKLE_FLAGS[@]}"

APP="build/UsageBar.app"
rm -rf "$APP"
if [[ "$SPARKLE" == 1 ]]; then
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
else
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
fi
cp icon/AppIcon.icns "$APP/Contents/Resources/"
cp "$BIN" "$APP/Contents/MacOS/UsageBar"

SPARKLE_PLIST_KEYS=""
if [[ "$SPARKLE" == 1 ]]; then
  # Sparkle is a dynamic framework at @executable_path/../Frameworks; it carries its XPC
  # services and the Autoupdate helper, so the whole framework is copied.
  cp -R .build/sparkle/Sparkle.framework "$APP/Contents/Frameworks/"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/UsageBar" 2>/dev/null || true
  SPARKLE_PLIST_KEYS="
  <key>SUFeedURL</key><string>https://raw.githubusercontent.com/Marcus1571/usagebar/main/appcast.xml</string>
  <key>SUPublicEDKey</key><string>4X6j0DXdJCmcxqe3fkMKWxKuuHhhM+rYrK5LauHe9UA=</string>
  <key>SUEnableAutomaticChecks</key><true/>
  <key>SUScheduledCheckInterval</key><integer>604800</integer>
  <key>SUAutomaticallyUpdate</key><true/>"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleName</key><string>UsageBar</string>
  <key>CFBundleExecutable</key><string>UsageBar</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${NUMERIC_VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>${SPARKLE_PLIST_KEYS}
</dict></plist>
PLIST

# Sign deepest-first: the Sparkle framework (XPC services, Updater.app, Autoupdate helper)
# needs a valid signature before the app can even attempt notarization.
if [[ "$SPARKLE" == 1 ]]; then
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --deep --sign - "$APP/Contents/Frameworks/Sparkle.framework"
    codesign --force --deep --sign - "$APP"
  else
    codesign --force --options runtime --timestamp --deep --sign "$SIGN_IDENTITY" "$APP/Contents/Frameworks/Sparkle.framework"
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
  fi
else
  codesign --force --sign "$SIGN_IDENTITY" "$APP"
fi
echo "Built $APP (version ${VERSION}, build ${NUMERIC_VERSION})"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x UsageBar 2>/dev/null || true
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/UsageBar.app"
  cp -R "$APP" "$HOME/Applications/UsageBar.app"
  echo "Installed ~/Applications/UsageBar.app"
fi
