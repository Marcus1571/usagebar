# Contributing

Small project, small rules.

1. **Stay read-only.** Never write tokens, Keychain items or provider config. The one allowed side effect is asking a provider's own CLI to renew itself (see `Grok.renewViaCLI`).
2. **No dependencies.** Plain Swift, SwiftUI and AppKit.
3. **Parsers get a check.** When a provider's response changes, add the real response shape to `Sources/UsageBar/SelfTest.swift` first and make it fail, then fix the parser. Run `build/UsageBar --selftest`.
4. **Never commit secrets.** Test data must be fake. Do not paste real tokens or account IDs into issues either.
5. **Adding a provider:** add a case to `Provider`, a client in `Fetch.swift` that reads its CLI's own credentials, and a self-test.

Build with `./scripts/build-app.sh` and check the popover in both light and dark mode before opening a pull request.
