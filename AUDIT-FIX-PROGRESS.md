# Bug Hunt Progress Tracker

_Last updated: 2026-09-27_

## Reported (pending fix)

| ID     | Finding                                                                                                   | Domain          | Category | Reported   |
| ------ | --------------------------------------------------------------------------------------------------------- | --------------- | -------- | ---------- |
| BH-007 | Classic tray menu (`TrayMenu=system` only) shows no shortcut hints until Settings is saved: built before settings load (`Clipnik.ahk:225`) | Configuration   | COULD    | 2026-09-27 |

## Fixed

| ID     | Finding | Domain | Category | Fixed In |
| ------ | ------- | ------ | -------- | -------- |
| BH-001 | Editing an image clip does not save the edit: the new dump is appended to the old `.avc`, so pasting still gives the original image while the thumbnail shows the edit (`Clipnik.ahk:2065`) | Data mutations | MUST | b85a695 |
| BH-002 | "Copy file data" cannot read Clipnik's own `.cnk` exports; it puts the raw bytes on the clipboard as text (`Clipnik.ahk:1806`) | Input handling | MUST | b85a695 |
| BH-003 | Setting "Days to store" back above 0 does not resume history recording until restart: `NOINCOGNITO` is never restored (`src/core/settings.ahk:382`) | Configuration | MUST | b85a695 |
| BH-004 | After a clip edit that is closed normally, the next Esc anywhere in Windows is swallowed and runs `ProcessClose` on the editor's stale PID (`Clipnik.ahk:2048`) | State machines | MUST | b85a695 |
| BH-005 | A Windows theme or accent change while Settings is open rebuilds the window and silently discards unsaved edits (`src/ui/native/SettingsWin.ahk` `Rebuild`) | Rendering | SHOULD | b85a695 |
| BH-006 | Pressing A while browsing the Vault makes the first V after leaving it jump to the newest clip (`Clipnik.ahk:1099` `navigate_to_first`) | State machines | SHOULD | b85a695 |
| BH-008 | Help says "Days to store: 0 keeps everything", but 0 turns history off, as the Settings hint says (`ui/help/topics/reference-settings.html`) | Documentation | COULD | b85a695 |

Fixed before this tracker existed (from git history): Snipping Tool double write recorded twice (7864a6c), compaction misaligning clip prefs (cd0b056), popups falling out of the topmost band (460f0d5), tray icon unreadable on dark taskbars (e97d45a), check marks off-center (880af02), search in paste mode disposed mid-scan (75bc509), empty text copies recorded (71e4640), copy path recording the snapshot (28e9588), image actions treating a missing image as the clipboard (ac3272e), action ring exceptions and held modifiers (d9d0bf4), Z menu stray hotkeys (bffe74c), paste card hotkey thread limit (94eee7c).

## False Positives / Dropped

| ID     | Finding                                                                                     | Domain         | Why Dropped                                                                                                                   |
| ------ | ------------------------------------------------------------------------------------------- | -------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| BH-D01 | A second copy while a protected-channel confirm is open re-enters `clipChange` and writes the wrong `.avc` | Concurrency    | AutoHotkey v2 docs: a clipboard change while an OnClipboardChange callback is running is lost, not re-entered. The second copy is simply not recorded. |
| BH-D02 | Organizer move/transfer/delete-channel race a clipboard copy (no `Critical` in `API.manageClip`) | Concurrency    | Needs another program to write the clipboard within the milliseconds an Organizer operation takes while the user is working in the Organizer: theoretical. |
| BH-D03 | `compacter()` could delete a fixed (pinned) clip                                             | Data mutations | `manageFIXATE()` moves fixed clips up as fast as compaction removes from the bottom, so they never reach the deleted range. |
| BH-D04 | Clip text injected into the History/Organizer/Help HTML                                      | Rendering      | Every template escapes through `cj.esc` / `hlWords`; image URLs come from `WebHost.CacheUrl`, never from clip text.          |
| BH-D05 | Organizer acts on the wrong clip after a re-sort or refresh                                  | Rendering      | Selection is tracked by id/n and re-derived from the current channel strength on every call.                                  |
| BH-D06 | Settings keys saved and loaded with different capitalization                                 | Configuration  | `v.CaseSense := "Off"`, and ini key names are case-insensitive in the Windows API.                                            |
