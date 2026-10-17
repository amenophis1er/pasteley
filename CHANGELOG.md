# Changelog

Each version has a section. The release workflow reads the section matching the tag and uses it for both the GitHub release notes and the update dialog in the app.

## Unreleased

## 0.1.0

The first release of Pastely, a light, local-only clipboard manager for macOS.

- History panel on ⇧⌘V, opening next to your cursor. Fuzzy search, filters for text, images, files and pinned items, live preview, keyboard-first flow.
- Text, rich text, images and file references.
- On-device text recognition for images: search finds words inside screenshots, and ⇧↩ pastes the recognized text.
- Encrypted history (AES-GCM, key in your login keychain). Concealed copies from password managers are never recorded. Ignore list by app. Retention by count and age.
- Welcome screen on first launch for the shortcut, the Accessibility permission and launch at login.
- Automatic updates through Sparkle from GitHub Releases.
- `pastely://` URL scheme for launchers and scripts.
