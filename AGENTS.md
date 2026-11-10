# AGENTS.md — UsageBar

**Read first:** at the start of every session in this project, read `GOVERNANCE.md` and
`USER.md` from their working copy, the operator's private governance repository on GitHub
(backups: the Obsidian vault on the home server and Notion; see GOVERNANCE.md, "The two fixed,
universal files"). They hold the operator's cross-project defaults. This file governs
when the two disagree on a project-specific fact; cross-cutting principles (secrets
handling, destructive-action caution) still apply here regardless.

## What this project is

A native macOS menu-bar app (SwiftUI + AppKit, no dependencies) that shows the remaining
quota of the operator's AI coding subscriptions. Public repo. Pitch: [README.md](README.md);
reference: [KB.md](KB.md); state: [STATUS.md](STATUS.md).

## Rules

- **Read-only, always.** Never write a token, a Keychain item or any provider config, and
  never refresh a provider's OAuth token: the official CLIs rotate refresh tokens and a
  second refresher signs them out. If a login is stale, tell the user (or let the CLI renew
  itself) instead.
- **Credentials go only to the provider's own host.** No telemetry, no third-party service.
- **No dependencies, one module, plain `swiftc`** (`scripts/build-app.sh`). Do not introduce
  SwiftPM or an Xcode project: SwiftPM is broken on some Command Line Tools versions.
  The packaged build is the one deliberate exception: `SPARKLE=1` fetches a pinned,
  hash-verified Sparkle release into `.build/sparkle/` (never committed) and links the
  updater; the source only touches it via `#if canImport(Sparkle)`, so the dev build
  (and `build/UsageBar --selftest`) stays dependency-free.
- **Public repo: never commit certificates, signed binaries, team IDs or Apple account
  details**, and no infra values (hostnames, IPs). The global gitleaks pre-commit hook guards
  secrets; never bypass it.
- **Before every commit:** `build/UsageBar --selftest` must pass. A new provider or a changed
  response shape gets a self-test built from a real response shape (with values anonymised).
- **Energy is a feature:** no observers that can re-trigger rendering, no work while the
  popover is closed, timers with tolerance. Check idle CPU after UI changes (the 0.1.1 bug).
- **Releases** follow USER.md's release sequence: bump `CFBundleShortVersionString` in
  `scripts/build-app.sh`, CHANGELOG section, tag, `gh release create`, push.

- **Public distribution additions since v0.6.0** (mirroring diskled-plus and
  NeverSleep, and replacing the plist hand-bump above — the version now follows
  the latest CHANGELOG heading): after the version+docs commit and before
  `gh release create`: `SIGN_IDENTITY="Developer ID Application: Marco Dal Moro
  (NGPL7S3YX3)" scripts/make-dmg.sh` (signs, notarizes and staples via the shared
  `diskledplus-notary` profile), then `scripts/make-appcast.sh <version>`
  (regenerates `appcast.xml`, committed in the release commit), then attach the
  DMG as the GitHub Release asset. Push order matters: tag + release with the
  asset live **before** `git push origin main`, so the appcast's enclosure URL is
  valid once main's feeder readers see it.
