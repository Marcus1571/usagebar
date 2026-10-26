#!/bin/zsh
# Builds build/UsageBar.app and signs it (ad hoc by default: no Apple developer account needed).
# Pass --install to also copy it to ~/Applications.
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"   sign with your own certificate
#   BUNDLE_ID=com.example.usagebar                                  use your own bundle identifier
set -euo pipefail
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
BUNDLE_ID="${BUNDLE_ID:-local.usagebar}"
cd "${0:A:h:h}"

# Plain swiftc: SwiftPM is broken with some Command Line Tools versions, and this is one module.
mkdir -p build
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macosx14.0" Sources/UsageBar/*.swift -o build/UsageBar
BIN="build/UsageBar"

APP="build/UsageBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp icon/AppIcon.icns "$APP/Contents/Resources/"
cp "$BIN" "$APP/Contents/MacOS/UsageBar"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.usagebar</string>
  <key>CFBundleName</key><string>UsageBar</string>
  <key>CFBundleExecutable</key><string>UsageBar</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
sed -i '' "s|local.usagebar|$BUNDLE_ID|" "$APP/Contents/Info.plist"
codesign --force --sign "$SIGN_IDENTITY" "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x UsageBar 2>/dev/null || true
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/UsageBar.app"
  cp -R "$APP" "$HOME/Applications/UsageBar.app"
  echo "Installed ~/Applications/UsageBar.app"
fi
