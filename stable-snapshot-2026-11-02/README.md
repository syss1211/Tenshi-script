# Saved stable public snapshot

Saved at the owner's request on 2026-11-02. This branch is a backup, not an automatic deployment.

- Original classic four-field broadcast, every 20 seconds.
- Highest 15 eggs per reporter; public Top 1 through Top 30.
- No carry/presence/recovery changes or fake preview animals.
- Root `Tenshi-Finder-Beta.lua` is the exact saved packed client (Git blob `ccbf054a24b9aa8e0813234fa961aacdc9951a9a`).
- Root `NYX.lua` is the exact saved loader, pinned to immutable stable client commit `51cd543abedbe78db2647c22a11f2d8282d9800e`.
- Source and service code are archived in this directory. Existing host configuration is required to run the service; it is not included in this backup.
- Running the client uses the existing public reporting host, just like the saved version. Uploading this branch does not restart or change the running host.

Test loader:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/syss1211/Tenshi-script/backup-stable-2026-11-02/NYX.lua"))()
```
