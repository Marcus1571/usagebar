# KB: UsageBar reference

Exhaustive reference. The pitch, provider table and quick build steps are in
[README.md](README.md); release history in [CHANGELOG.md](CHANGELOG.md).

## Behavior constants

| What | Value | Where |
|---|---|---|
| Refresh interval | 300 s, timer tolerance 60 s | `main.swift` |
| Extra refreshes | on wake and when the popover opens, never more than once a minute | `Store.swift` |
| Colour thresholds | orange at 40 % left or less, red at 20 % left or less (bars: green above 40 %) | `Views.swift` |
| Stale data | a failed fetch keeps the last good snapshot, shown dimmed | `Model.swift` |
| Claude login | cached in memory until it expires; HTTP 401/403 clears it and shows "use Claude Code once" | `Fetch.swift` |
| Grok renewal | when the token is stale, runs `grok models` at most once every 20 minutes | `Fetch.swift` |

## Signing and distribution

This repository ships **no certificates, no signed binaries and no Apple account details**. You build and sign your own copy:

- **Default:** ad-hoc signature (`codesign --sign -`). It runs fine on the Mac that built it and needs no Apple account.
- **Your own certificate:** `SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-app.sh` signs with your Developer ID. Notarize it yourself with `xcrun notarytool` if you want to hand it to other people without a Gatekeeper warning.
- **Your own bundle id:** the default is `local.usagebar`; override it with `BUNDLE_ID=com.example.usagebar`.
- **Sharing an ad-hoc build:** Gatekeeper blocks a downloaded copy on another Mac. Open System Settings → Privacy & Security and choose **Open Anyway**, or run `xattr -dr com.apple.quarantine UsageBar.app`. Building from source on that Mac avoids the warning.

## Command line

```sh
build/UsageBar --selftest        # parser checks against real response shapes (no network)
build/UsageBar --dump            # fetch once and print the numbers, no UI
build/UsageBar --render DIR      # write label and popover PNGs with live data
build/UsageBar --open            # launch and auto-open the popover (handy for screenshots)
```

## Project layout

```
Sources/UsageBar/
  Model.swift      Provider, UsageWindow, Snapshot, ProviderState
  Fetch.swift      credentials readers and the three provider clients
  Store.swift      refresh logic (rate limit, concurrent fetch, keeps last good data)
  Views.swift      menu-bar label (rendered to an image) and popover
  SelfTest.swift   parser and formatting checks
  main.swift       app delegate, status item, CLI modes
scripts/build-app.sh   build, bundle, sign, install
scripts/make-icon.sh   icon/icon.svg -> icon/AppIcon.icns (needs librsvg)
```


## Build environment variables

| Variable | Default | Effect |
|---|---|---|
| `SIGN_IDENTITY` | `-` (ad-hoc) | codesign identity used by `scripts/build-app.sh` |
| `BUNDLE_ID` | `local.usagebar` | bundle identifier of the built app |
