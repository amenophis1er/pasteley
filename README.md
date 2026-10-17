# Pasteley

A small, local-only clipboard manager for macOS. Menu bar app, one hotkey, searchable history for text, rich text, images and files. Nothing leaves the Mac.


## Run

```sh
swift build && .build/debug/Pasteley     # dev run (no bundle, no Dock icon)
./scripts/bundle.sh && open Pasteley.app  # app bundle, ad-hoc signed
swift test
```

## Using it

- **Cmd+Shift+V** opens the history panel (change it in Settings). Type to fuzzy-search, Tab cycles the filter, Return pastes, Shift+Return pastes plain text, Cmd+1…9 pastes the nth row, Cmd+P pins, Cmd+Backspace deletes.
- **Menu bar icon** lists the 10 newest items, pause/resume capture, Settings.
- **Settings** (Cmd+,): hotkey recorder, launch at login, Accessibility status, retention, image cap, ignored apps.
- **URL scheme** for launchers and scripts: `open pasteley://history`, `pasteley://settings`, `pasteley://pause`, `pasteley://resume`.

## Layout

| Path | What |
| --- | --- |
| `Sources/Pasteley/DesignSystem.swift` | Theme tokens and shared components |
| `Sources/Pasteley/HistoryPanel.swift` | Floating panel, filters, list, preview pane |
| `Sources/Pasteley/SettingsView.swift` | Settings tabs |
| `Sources/Pasteley/AppSettings.swift` | Persisted preferences |
| `Sources/Pasteley/ClipStore.swift` | SQLite + AES-GCM history |
| `Sources/Pasteley/PasteboardWatcher.swift` | Capture and privacy filters |
| `scripts/make-icon.swift` | Regenerates `Resources/AppIcon.icns` |

Default hotkey: Cmd+Shift+V. Pasting into the front app needs Accessibility permission, which macOS prompts for on first paste.

## Signing note

The encryption key lives in the login keychain, and the keychain remembers "Always Allow" per code identity. `scripts/bundle.sh` therefore signs with your Apple Development certificate by default so the identity stays stable across builds. Running the raw `.build/debug/Pasteley` binary uses a different identity and will prompt. Override with `SIGN_IDENTITY="Developer ID Application: …" ./scripts/bundle.sh` for distribution.
