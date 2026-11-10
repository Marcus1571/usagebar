#!/bin/zsh
# Builds a distribution DMG: build/dist/UsageBar-<version>.dmg — Developer ID signed,
# notarized and stapled when the notary keychain profile exists.
#
# Usage: SIGN_IDENTITY="Developer ID Application: Marco Dal Moro (NGPL7S3YX3)" scripts/make-dmg.sh
#
# Notarization runs against the keychain profile "diskledplus-notary" (shared with
# diskled-plus and NeverSleep — same Apple ID). When it exists, the DMG is notarized
# and stapled; otherwise you get a warning: an unsigned/unnotarized DMG is acceptable
# only on the build host — Gatekeeper blocks it on other machines.
set -euo pipefail
NOTARY_PROFILE="diskledplus-notary"
STAGING="build/dmg-staging"
cd "${0:A:h:h}"

VERSION="${VERSION:-$(grep -m1 -oE '^## [0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md | sed 's/^## //')}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
DMG="build/dist/UsageBar-${VERSION}.dmg"

SIGN_IDENTITY="$SIGN_IDENTITY" SPARKLE=1 ./scripts/build-app.sh

rm -rf "$STAGING"
mkdir -p "$STAGING" build/dist
cp -R build/UsageBar.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -volname "UsageBar" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

# The DMG container itself is notarized (Apple best practice).
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi

set +e
SUBMIT_OUTPUT="$(xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1)"
SUBMIT_STATUS=$?
set -e
if [ $SUBMIT_STATUS -eq 0 ]; then
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  echo "Notarized + stapled: $DMG"
elif echo "$SUBMIT_OUTPUT" | grep -qi "keychain\|credential"; then
  echo "WARNING: notary keychain profile '$NOTARY_PROFILE' not found."
  echo "DMG built but NOT notarized: $DMG"
  echo "Gatekeeper will block this on machines other than the build host."
  echo "Run: xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <your Apple ID> --password <app-specific password> --team-id <TEAMID>"
else
  echo "Notarization submit failed:"
  echo "$SUBMIT_OUTPUT"
  exit 1
fi
