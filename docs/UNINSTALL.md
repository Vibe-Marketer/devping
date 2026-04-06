# Uninstall

## Remove DevPing app

If installed via Homebrew:

```bash
brew uninstall devping
brew untap vibe-marketer/devping
```

If installed manually, remove the binary or app bundle you installed.

## Remove DevPing hook script

```bash
rm -f ~/.config/devping/hooks/notify.sh
```

## Remove DevPing config entries from supported tools

### Claude Code
Remove DevPing hook entries from:

- `~/.claude/settings.json`

### OpenCode
Remove DevPing hook entries from:

- `~/.config/opencode/settings.json`

### Aider
Remove the DevPing notifications entry from:

- `~/.aider.conf.yml`

## Local settings

If you want to remove local preferences as well, delete the DevPing user defaults domain.

This step should be documented with the exact command once the final bundle identifier and release process are locked.

## Recommended improvement

Before launch, DevPing should ship a clean uninstall helper or documented repair/uninstall flow.
