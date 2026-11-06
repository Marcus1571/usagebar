# findings

Research log, newest first.

## 2026-11-01: idle CPU at about 90 % of a core

The menu-bar label observed the status button's `effectiveAppearance` and re-set its image
when it changed; macOS answers a new image by changing the appearance again, so the app
redrew in an endless loop. Verdict: draw the label as one image that renders itself in the
menu bar's own appearance, with no observer, re-rendered only when a displayed number or
colour changes. Idle CPU dropped to about 0 %. Released in CHANGELOG 0.1.1.

## 2026-10/11: where each provider's quota comes from

Each official CLI keeps a login and calls an undocumented usage endpoint; UsageBar reads the
same credentials read-only and calls the same endpoint (table in README). Decided against
refreshing tokens ourselves after finding that a second refresher can sign the CLI out.
Grok's token is renewed by running `grok models`, throttled to once per 20 minutes.
