# Security

UsageBar reads local credentials of other tools and sends them to those tools' own API hosts, so a bug here matters.

- It must never write or refresh tokens, and must never send a credential anywhere except the provider's own host listed in the README.
- Found a problem? Please open a private security advisory on GitHub (Security tab → Report a vulnerability) instead of a public issue.
- Supported: the latest release only.
