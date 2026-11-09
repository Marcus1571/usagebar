# findings

Research log, newest first.

## 2026-11-09: more providers

Candidates checked against the read-only rules (method notes from CodexBar's public docs, then
verified where an account was available):

- **GitHub Copilot:** `GET api.github.com/copilot_internal/user` with the GitHub CLI token
  (`gh auth token`) returns `quota_snapshots` (chat, completions, premium_interactions:
  `entitlement`, `percent_remaining`, `unlimited`) and `quota_reset_date_utc`. Verified on a
  Free plan (premium entitlement 0). Verdict: adopted in 0.3.0.
- **Antigravity:** its local language server (`language_server_macos_*`, started with
  `--csrf_token`) answers Connect calls on 127.0.0.1 (`RetrieveUserQuotaSummary`,
  fallback `GetUserStatus`) with Gemini and Claude/GPT pools. Nothing leaves the Mac. Verdict:
  next, once a real response is captured with Antigravity running.
- **Gemini CLI:** Google shut down Gemini CLI OAuth for individual, AI Pro and Ultra accounts in
  June 2026, and its token lasts an hour and must not be refreshed by us. Verdict: skip; use
  Antigravity for Gemini quota.
- **Cursor:** needs browser session cookies. Verdict: skip (outside read-only CLI credentials).
- **Kiro, z.ai, Windsurf, Augment, Factory, Amp:** possible, each needs an account to verify.

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
