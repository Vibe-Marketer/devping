# Permissions

DevPing is a macOS utility that may interact with other apps to return you to the correct editor or terminal window.

## Permissions DevPing may rely on

### 1. Automation / Apple Events
DevPing may use AppleScript / Apple Events to bring certain editors or terminals to the front.

This can trigger a macOS permission prompt depending on the target app and your system state.

### 2. Notifications / sound behavior
DevPing plays local sounds and displays its own notification-style panels.

### 3. Accessibility (future / optional depending on implementation)
If future workflows require deeper app interaction, accessibility permissions may become relevant. If that happens, the product and docs should explain exactly why.

## Why DevPing may need app automation
Some focus actions depend on telling a target app to:

- activate
- bring a matching window forward
- select the correct tab/session

This is especially relevant for:

- Terminal.app
- iTerm2
- editor window targeting

## Launch requirement
Before public launch, DevPing should clearly explain:

- what permission prompt a user might see
- why it appears
- what still works without it
- how to disable or remove the behavior
