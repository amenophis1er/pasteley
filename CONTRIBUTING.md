# Contributing

Pastely is a small personal project. Issues and pull requests are welcome, with two rules of thumb.

- Keep it light. No third-party dependencies, no network code. If a feature needs either, open an issue first.
- Keep it private. Anything that touches what gets recorded, stored or sent needs a note in `SECURITY.md`.

## Building

```sh
swift build && swift test       # library + tests
./scripts/bundle.sh             # Pastely.app signed with your Apple Development cert
make release                    # Developer ID signed, notarization-ready
```

Requires Xcode 27 on macOS 26. The app targets macOS 15 and Apple silicon.
