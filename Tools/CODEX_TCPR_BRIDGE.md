# In-game Codex TCPR bridge

This development-only bridge turns explicit moderator chat commands into serialized Codex CLI jobs. Ordinary chat is ignored.

## KAG setup

Run this from the mod directory in a separate PowerShell window:

```powershell
.\Tools\Start-CodexTCPRBridge.ps1
```

The launcher reads the KAG installation's root `autoconfig.cfg`. If needed, it securely prompts for a local password and configures:

```cfg
sv_tcpr = true
sv_tcpr_everything = false
sv_tcpr_timestamp = false
sv_rconpassword = <the password you entered>
```

TCPR listens on `sv_port` (`50301` by default). Keep it behind a firewall; it is a remote console, not a safe public API.

Start or restart KAG normally in a visible window with this mod enabled. The bridge waits and reconnects automatically. For a remote server, pass `-HostName` and `-SkipConfig`, then set `KAG_TCPR_PASSWORD` in the terminal first.

Moderators can inspect or toggle the listener while the game is running:

```text
!tcpr status
!tcpr on
!tcpr off
```

`!tcpr on` requires `sv_rconpassword` to already be configured. Passwords are deliberately not accepted through chat because chat can be logged.

## In-game commands

Only players with KAG moderator status can use these commands:

```text
!codex make the AI builder marker green
!codex status
!codex cancel
```

Requests are queued and executed one at a time with `codex exec`, workspace-write sandboxing, and no interactive approvals. On exit code 0, the bridge posts Codex's final summary to global game chat and sends `rebuild()` through TCPR. Failed or cancelled runs do not rebuild.

The bridge reconnects automatically if KAG restarts. Stop it with `Ctrl+C`.
