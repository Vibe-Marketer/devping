# Release Process

## Goal
Produce a clean direct-download release artifact for DevPing.

## Current state
- local build works
- app bundle assembly works
- current signing is ad-hoc only
- notarization is not yet configured

## Release steps

1. Bump version in `Info.plist`
2. Build release app bundle
3. Sign with Developer ID Application certificate
4. Enable Hardened Runtime as needed
5. Notarize the app
6. Staple the notarization ticket
7. Zip or package the release artifact
8. Verify with `spctl`
9. Upload to GitHub Releases / website / Homebrew pipeline

## Commands to automate
Suggested script responsibilities:

- call `./scripts/build-app.sh --release`
- package `build/DevPing.app`
- create versioned zip name
- optionally run signing/notarization if env vars or credentials are present

## Launch requirement
No public direct-download launch should happen until the release artifact passes Gatekeeper verification.
