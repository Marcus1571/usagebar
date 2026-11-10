# STATUS

Last updated 2026-11-10.

- **Providers:** Claude, Codex (ChatGPT), Grok, OpenCode Go, GitHub Copilot. Next candidate: Antigravity (local language-server quota; needs Antigravity running to capture a real response). See findings.md.
- **Released:** v0.6.0 (2026-11-10): public-app distribution — Developer ID-signed, notarized + stapled DMG, Sparkle 2.10.1 self-updating (appcast on repo main, EdDSA key shared with diskled-plus/NeverSleep), "Check for Updates…" in Settings; bundle id changed to `com.usagebar.app` (one-time local settings reset). v0.5.0 (same day): Settings window (provider show/hide, label style with live preview, refresh interval). v0.4.0 (same day): provider show/hide gear menu in the popover (superseded by the Settings window). v0.3.0 (2026-11-09): GitHub Copilot provider, signed-out providers hidden in the popover too, scrolling popover. v0.2.1 (same day) hid signed-out providers from the menu bar; v0.2.0 (2026-11-07) added OpenCode Go and the 0.1.1 energy fix.
- **Known risk:** all four usage endpoints are undocumented and can change without notice.
