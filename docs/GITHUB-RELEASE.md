# GitHub Release Copy

## Title

DevPing v1.2.6 — notarized direct launch build

## Release summary

DevPing is a native macOS notifier for AI coding tools.

This release is prepared for direct download and includes:

- native macOS notifications for supported AI tools
- settings UI for sound, timing, and appearance
- improved hook install cleanup
- cleaner launch documentation
- notarized Developer ID build for safer installation

## Highlights

- Completion alerts for supported AI coding tools
- Permission-needed alerts
- Menu bar app with test notification flow
- Smarter installer behavior with duplicate hook cleanup
- Updated privacy, support, permissions, uninstall, and launch docs
- Direct-download release path with notarized app bundle

## Install

### Homebrew

```bash
brew tap vibe-marketer/devping
brew install devping
devping-setup
```

### Manual

Download the release zip, extract `DevPing.app`, move it to Applications, and launch it.

## Notes

This release is focused on the direct-download launch path.

The Mac App Store path is intentionally deferred while the product remains optimized for local tool integration and desktop workflow utility.
