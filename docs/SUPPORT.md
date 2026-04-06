# Support

## Getting help

If DevPing is not working correctly, start with these checks:

1. Confirm DevPing is installed and running
2. Open DevPing and send a test notification
3. Re-run setup if the supported AI tool has not been connected yet
4. Check the tool-specific config file for hook installation
5. Review the permissions guide if window focusing or automation is failing

## Common issues

### No notification appears
- Make sure DevPing is running
- Make sure the tool hook is installed
- Make sure popup notifications are enabled in settings
- Try a test notification from the menu bar

### Sound plays but no popup appears
- DevPing may have detected that your editor is already focused
- Check focus behavior settings
- Check whether popup notifications are disabled

### Wrong editor or terminal is focused
- Confirm the tool is running in a supported editor or terminal
- Re-run setup
- Check permissions for automation if window focus relies on AppleScript

### Hook duplication or strange repeat behavior
- Re-run the installer once a repair pass is available
- Check the supported tool config file for duplicate DevPing entries

## Recommended support docs

- [`PRIVACY.md`](./PRIVACY.md)
- [`PERMISSIONS.md`](./PERMISSIONS.md)
- [`WHAT-DEVPING-CHANGES.md`](./WHAT-DEVPING-CHANGES.md)
- [`UNINSTALL.md`](./UNINSTALL.md)

## Product contact

Suggested public support endpoints for launch:

- support email
- GitHub issues
- community link

These should be finalized before the public launch.
