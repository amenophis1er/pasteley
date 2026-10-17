# Pastely

A small, local-only clipboard manager for macOS. Menu bar app, one hotkey, searchable history for text, rich text, images and files. Nothing leaves the Mac.

## Install

Download the latest `Pastely-x.y.z.dmg` from [Releases](https://github.com/amenophis1er/pastely/releases/latest), open it and drag Pastely to Applications. The app is signed with a Developer ID and notarized by Apple.

## Run from source

```sh
swift build && .build/debug/Pastely     # dev run (no bundle, no Dock icon)
./scripts/bundle.sh && open build.noindex/dev/Pastely.app  # dev bundle, Apple Development signed
swift test
```

## Using it

- **Cmd+Shift+V** opens the history panel (change it in Settings). Type to fuzzy-search, Tab cycles the filter, Return pastes, Shift+Return pastes plain text, Cmd+1…9 pastes the nth row, Cmd+P pins, Cmd+Backspace deletes.
- **Menu bar icon** lists the 10 newest items, pause/resume capture, Settings.
- **Settings** (Cmd+,): hotkey recorder, launch at login, Accessibility status, retention, image cap, ignored apps.
- **URL scheme** for launchers and scripts: `open pastely://history`, `pastely://settings`, `pastely://pause`, `pastely://resume`.

## Layout

| Path | What |
| --- | --- |
| `Sources/Pastely/DesignSystem.swift` | Theme tokens and shared components |
| `Sources/Pastely/HistoryPanel.swift` | Floating panel, filters, list, preview pane |
| `Sources/Pastely/SettingsView.swift` | Settings tabs |
| `Sources/Pastely/AppSettings.swift` | Persisted preferences |
| `Sources/Pastely/ClipStore.swift` | SQLite + AES-GCM history |
| `Sources/Pastely/PasteboardWatcher.swift` | Capture and privacy filters |
| `scripts/make-icon.swift` | Regenerates `Resources/AppIcon.icns` |

## Releasing

Tag a commit and push it. CI builds, signs, notarizes and publishes the DMG to GitHub Releases:

```sh
git tag v0.1.0 && git push origin v0.1.0
```

Locally, `make dmg` does the same with your Developer ID certificate and the `pastely-notary` keychain profile.

Default hotkey: Cmd+Shift+V. Pasting into the front app needs Accessibility permission, which macOS prompts for on first paste.

## Signing note

The encryption key lives in the login keychain, and the keychain remembers "Always Allow" per code identity. `scripts/bundle.sh` therefore signs with your Apple Development certificate by default so the identity stays stable across builds. Running the raw `.build/debug/Pastely` binary uses a different identity and will prompt. Override with `SIGN_IDENTITY="Developer ID Application: …" ./scripts/bundle.sh` for distribution.
