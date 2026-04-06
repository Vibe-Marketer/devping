# What DevPing Changes

DevPing integrates with supported AI coding tools by installing hook commands in local configuration files.

## Supported config locations

### Claude Code
- `~/.claude/settings.json`

### OpenCode
- `~/.config/opencode/settings.json`

### Aider
- `~/.aider.conf.yml`

## DevPing hook location

DevPing writes its managed hook script to:

- `~/.config/devping/hooks/notify.sh`

## What the installer should guarantee

The installer should:

- create the DevPing hook directory if missing
- write or update the managed DevPing hook script
- add DevPing hook entries only once
- remove duplicate DevPing entries if found
- avoid damaging unrelated hooks
- avoid forcing users to hand-edit config files

## What DevPing should not do

DevPing should not:

- remove unrelated hooks unexpectedly
- overwrite unrelated tool configuration without need
- install duplicate entries repeatedly
- require users to manually patch JSON/YAML unless recovery is needed

## Launch note

This file should stay accurate as integrations evolve. If new tools are added, they should be documented here before launch.
