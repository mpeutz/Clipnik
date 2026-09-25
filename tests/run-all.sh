#!/bin/bash
# Runs the whole test suite from Git Bash. Unit tests run standalone; the rest need a RUNNING Clipnik
# (start it with Clipnik.cmd, or tools/run-test.ps1) and will type into their own test windows.
# Do not use the keyboard or clipboard while the interactive part runs.
cd "$(dirname "$0")/.."
run() {
  echo "=== $1"
  MSYS_NO_PATHCONV=1 timeout "${2:-120}" ./runtime/AutoHotkey64.exe /ErrorStdOut "tests/$1" | grep -E "FAIL|PASSED|\.\." 
  rc=${PIPESTATUS[0]}
  [ "$rc" != "0" ] && { echo "!!! $1 exit=$rc"; failed=1; }
}
failed=0
echo "=== validate"; MSYS_NO_PATHCONV=1 timeout 60 ./runtime/AutoHotkey64.exe /ErrorStdOut /validate Clipnik.ahk && echo "validate ok" || { echo "!!! validate failed"; failed=1; }
run cjmap.ahk; run hotkeyparser.ahk; run sqlitedb.ahk; run clipfile.ahk; run cliptype.ahk; run transforms.ahk; run rules.ahk; run ring_geom.ahk; run zorder.ahk; run traytint.ahk; run history_kinds.ahk; run history_prune.ahk; run vault.ahk; run webhost_demo.ahk 60
if tasklist | grep -qi "AutoHotkey64.exe"; then
  run ring_pick.ahk 60;
  run api_client.ahk; run e2e.ahk 120; run pastemode.ahk 240; run modes.ahk 240; run image.ahk 120; run image_repeat.ahk 60; run windows.ahk 180; run windowops.ahk 240; run settings_flow.ahk 180; run ignored_flow.ahk 120; run history_flow.ahk 120; run vault_flow.ahk 120; run help_flow.ahk 120; run history_image.ahk 90; run organizer_flow.ahk 120; run rules_flow.ahk 90; run tray_shots.ahk 90
else
  echo "Clipnik is not running: interactive tests skipped"
fi
powershell -NoProfile -File tools/dialogs.ps1
[ $failed = 0 ] && echo "ALL SUITES PASSED" || echo "SOME SUITES FAILED"
exit $failed
