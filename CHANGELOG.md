# Changelog

## 0.8.1 - 2026-11-11

- About window restyled to match NeverSleep's (same layout, same conventions): 96 pt app icon, "Version x (build y)" from the bundle's two version keys, divider, **© 2026 Marcus1571** (public GitHub identity instead of the real name), the license line (UsageBar is MIT-only, so a single "MIT"), one link `github.com/Marcus1571/usagebar`, and a one-line tagline at the bottom. No behavior change.

## 0.8.0 - 2026-11-11

- New: an **About** line in the popover's footer (an ⓘ button between Refresh and Quit) opens a small About window in the standard macOS mini-page style: the app logo, name and version, a one-line description, the author (Marco Dal Moro), the MIT license note, and links to the GitHub repository and the LICENSE file.
- Code: new `AboutView` in `Settings.swift`; `main.swift` owns the `aboutWindow` (created on first open and kept for reuse, fixed size — same pattern as the Settings window); `PopoverView` gained an `onAbout` callback. `--render` now also writes the About window's PNGs (`about-light/dark.png`) for the docs set. The version line reads `CFBundleShortVersionString` from the bundle; a bare dev run shows "Development build" and an SF-symbol stand-in for the icon.

## 0.7.0 - 2026-11-11

- **Fix: settings survive bundle-id changes and app moves.** The four settings (Left/Used, hidden providers, label style, refresh interval) now live in `~/Library/Application Support/UsageBar/settings.json` instead of UserDefaults, which is keyed to the bundle identifier: 0.6.0's id change (`local.usagebar` → `com.usagebar.app`) made the app read a fresh domain on first launch and silently reset every setting to defaults (observed 2026-11-11 as Left/Used reverting to Left after a reboot). A file in a fixed folder cannot have that happen again.
- New `AppSettings.swift`: a small JSON-file settings store. On a first launch with no settings file it imports once from the old store — the standard UserDefaults domain (whatever the current bundle id is), with any key it lacks filled from the pre-0.6.0 `local.usagebar` domain — and the written file is the done-flag: the legacy plists are left untouched and never read again. An existing but unreadable file imports nothing, so stale legacy values can never overwrite newer choices.
- Code: `Store.swift`'s four settings read and write `AppSettings` instead of `UserDefaults.standard`; defaults and behavior unchanged. Sparkle's own keys (update checks) stay in UserDefaults.
- SelfTest: settings round-trip, one-time import (current domain wins, legacy fills gaps), no-re-import-after-the-file-exists checks against throwaway suites and a temp file.

## 0.6.0 - 2026-11-10

- Public-app distribution, same stack as diskled-plus and NeverSleep: Developer ID–signed app (hardened runtime, timestamped), notarized + stapled DMG, and Sparkle 2.10.1 self-updating (startup + weekly checks, automatic installs, "Check for Updates…" in Settings). The EdDSA appcast (`appcast.xml` on repo `main`) uses the operator's key pair shared with the sibling projects.
- New `Updater.swift`: Sparkle wrapper compiled only when the framework is present (`#if canImport(Sparkle)`), so the dev build stays dependency-free; it also refuses to start on a bare (non-bundle) run. Settings gained an Updates section with the manual check button.
- New scripts: `fetch-sparkle.sh` (pinned 2.10.1, SHA-256-verified, into gitignored `.build/sparkle`), `make-dmg.sh` (Developer ID + notarize + staple via the shared `diskledplus-notary` keychain profile), `make-appcast.sh` (signs the DMG with `sign_update`, writes `appcast.xml`). `build-app.sh` reworked: the version now follows the latest CHANGELOG heading (no more hand-bumped plist), `CFBundleVersion` is the numeric Sparkle stamp (0.6.0 → 600), `SPARKLE=1` builds to `build/UsageBar-dist` + bundle so the dev `build/UsageBar --selftest` binary is never clobbered, Developer ID signing uses hardened runtime + timestamp and signs the framework deepest-first, `NSHighResolutionCapable` added.
- **Bundle identifier changed** from `local.usagebar` to `com.usagebar.app` for the public release; existing local settings (hidden providers, label style, refresh interval) reset once on first launch of the new identifier.

## 0.5.0 - 2026-11-10

- New: a proper Settings window, opened from the popover's gear button (the 0.4.0 dropdown menu is gone; the gear opens Settings instead).
  - **Providers:** a toggle per provider to show/hide it (same never-blank-the-menu-bar guard; signed-out providers say so).
  - **Menu bar:** Left/Used, and the label style — Plain, Outline, Outline with dividers, Pill, Pill with outline — with a live preview drawn by the real label component using current data.
  - **Refresh:** fetch interval, 1/2/5/10/15 minutes (default 5). The repeating timer is rescheduled on change; tolerance scales down with short intervals.
- Code: new `Settings.swift` (`SettingsView`); `Store.swift` gained persisted `labelStyle` (default 4) and `refreshInterval` (default 300 s); `labelStyle` is threaded through `LabelView`, `labelKey()`, `renderLabel()`/`adaptiveLabel()` and included in the label key, so the image re-renders when the style changes. `main.swift` owns the settings `NSWindow` (created on first open, kept for reuse, fixed size) and reschedules the timer on `store.$refreshInterval`. `--render` also writes settings-window PNGs (the snapshot helper was generalised to `snapshotWindow`).
- `toggleHidden()` removed from `Store` — the Settings toggle binds directly to the hidden set.

## 0.4.0 - 2026-11-10

- New: a gear menu in the popover header shows or hides any provider — click it, then click a provider to toggle it; a checkmark means shown. Hidden providers are left out of the menu bar and the popover, and the choice persists across launches (UserDefaults `hiddenProviders`).
- Providers signed out are marked "Not signed in" inside the menu; hiding the last visible provider is disabled so the menu bar never goes blank.
- Code: `Model.swift` `shownProviders()` gained a `hidden` set parameter threaded through `LabelView`, `labelKey()` and the label renderers (`Views.swift`), so the label re-renders when only membership changes (key includes the filter; no new observers or timers). `Store.swift` holds the persisted `hiddenProviders` set with a `toggleHidden()` action. Docs screenshots' gear icon is a static look-alike, as with the other native controls.
## 0.3.0 - 2026-11-09

- New provider: GitHub Copilot (Premium requests, Chat and Completions for the month, from `api.github.com/copilot_internal/user`, using the GitHub CLI login via `gh auth token`, read-only). A GitHub account without Copilot is treated as not signed in.
- Providers without a login are now hidden in the popover as well as the menu bar, so unused providers never show up.
- The popover scrolls when its cards are taller than the screen.

## 0.2.1 - 2026-11-09

- A provider with no credentials on this Mac (for example OpenCode not logged in) is now left out of the menu bar instead of showing an orange "!". Its popover card shows a grey "Not signed in: run …" hint and does not turn the footer dot orange. Broken or expired logins and HTTP errors still show "!".

## 0.2.0 - 2026-11-07

- New provider: OpenCode Go (5-hour, weekly and monthly usage from the official `/zen/go/v1/usage` endpoint, key read from the OpenCode CLI's `auth.json`, read-only).

## 0.1.1 (released as part of 0.2.0)

- Fixed a CPU/energy bug: the menu-bar label was observing the status button's `effectiveAppearance` and re-setting its image, which macOS answers by changing the appearance again, so the app redrew in an endless loop (about 90% of a core). The label is now one image that draws itself in the menu bar's own appearance, with no observer, and is only re-rendered when a displayed number or colour changes.
- The popover's SwiftUI content is created when it opens and released when it closes, so nothing ticks while it is hidden.
- The 5-minute refresh timer has a 60 s tolerance so macOS can batch wake-ups.
- The Claude login is cached in memory until it expires, so the `security` process is no longer spawned on every refresh.

## 0.1.0

- First release: Claude, Codex and Grok limits in the menu bar and a popover.
- Left / Used toggle, colour by what is left, stale-data dimming.
- Menu-bar label follows the menu bar's own appearance, with a thin framed pill.
- Read-only credential handling, self-tests, ad-hoc signed `.app` build with icon.
