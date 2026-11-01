# Changelog

## 0.2.0

- New provider: OpenCode Go (5-hour, weekly and monthly usage from the official `/zen/go/v1/usage` endpoint, key read from the OpenCode CLI's `auth.json`, read-only).

## 0.1.1

- Fixed a CPU/energy bug: the menu-bar label was observing the status button's `effectiveAppearance` and re-setting its image, which macOS answers by changing the appearance again, so the app redrew in an endless loop (about 90% of a core). The label is now one image that draws itself in the menu bar's own appearance, with no observer, and is only re-rendered when a displayed number or colour changes.
- The popover's SwiftUI content is created when it opens and released when it closes, so nothing ticks while it is hidden.
- The 5-minute refresh timer has a 60 s tolerance so macOS can batch wake-ups.
- The Claude login is cached in memory until it expires, so the `security` process is no longer spawned on every refresh.

## 0.1.0

- First release: Claude, Codex and Grok limits in the menu bar and a popover.
- Left / Used toggle, colour by what is left, stale-data dimming.
- Menu-bar label follows the menu bar's own appearance, with a thin framed pill.
- Read-only credential handling, self-tests, ad-hoc signed `.app` build with icon.
