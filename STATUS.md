# STATUS

Last updated 2026-11-06.

- **Providers:** Claude, Codex (ChatGPT), Grok, OpenCode Go.
- **Code level:** CHANGELOG 0.2.0 (OpenCode Go added 2026-11-01).
- **Release drift:** only `v0.1.0` is tagged and released on GitHub, and the app's
  `CFBundleShortVersionString` still says `0.1`. The 0.1.1 energy fix and 0.2.0 were
  committed but never released. Next release should bump the bundle version and publish
  0.2.0 (or the next number) per the release sequence.
- **Known risk:** all four usage endpoints are undocumented and can change without notice.
