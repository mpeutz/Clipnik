#!/bin/bash
# Runs the whole test suite from Git Bash. Unit tests run standalone anywhere; the rest drive a running Clipnik,
# copying, pasting and deleting clips for real, so they run only inside a sandbox copy: tools/test-sandbox.sh
# builds one, starts its Clipnik and calls this script there. Do not use the keyboard or clipboard meanwhile.
# Test names as arguments run just those (tests/run-all.sh e2e.ahk vault_flow.ahk). Each test's full output
# is kept in tests/out/<test>.out.
cd "$(dirname "$0")/.."
mkdir -p tests/out
only=" $* "
run() {
  [ "$only" != "  " ] && [[ "$only" != *" $1 "* ]] && return
  echo "=== $1"
  MSYS_NO_PATHCONV=1 timeout "${2:-120}" ./runtime/AutoHotkey64.exe /ErrorStdOut "tests/$1" | tee "tests/out/${1%.ahk}.out" | grep -E "FAIL|PASSED|\.\." 
  rc=${PIPESTATUS[0]}
  [ "$rc" != "0" ] && { echo "!!! $1 exit=$rc"; failed=1; }
}
failed=0
echo "=== validate"; MSYS_NO_PATHCONV=1 timeout 60 ./runtime/AutoHotkey64.exe /ErrorStdOut /validate Clipnik.ahk && echo "validate ok" || { echo "!!! validate failed"; failed=1; }
run sandbox_guard.ahk; run cjmap.ahk; run hotkeyparser.ahk; run sqlitedb.ahk; run clipfile.ahk; run clipdump.ahk; run cliptype.ahk; run transforms.ahk; run rules.ahk; run ring_geom.ahk; run zorder.ahk; run traytint.ahk; run checkbox.ahk; run webthumbs.ahk; run menustyle.ahk; run history_kinds.ahk; run history_prune.ahk; run vault.ahk; run webhost_demo.ahk 60
if [ -f .clipnik-test-sandbox ]; then
  run ring_pick.ahk 60;
  run api_client.ahk; run e2e.ahk 120; run pastemode.ahk 240; run modes.ahk 240; run image.ahk 120; run image_repeat.ahk 60; run windows.ahk 180; run windowops.ahk 240; run settings_flow.ahk 180; run ignored_flow.ahk 120; run history_flow.ahk 120; run vault_flow.ahk 120; run help_flow.ahk 120; run history_image.ahk 90; run organizer_flow.ahk 120; run rules_flow.ahk 90; run tray_shots.ahk 90
else
  echo "Not a sandbox copy: interactive tests skipped (run tools/test-sandbox.sh for those)"
fi
powershell -NoProfile -File tools/dialogs.ps1
[ $failed = 0 ] && echo "ALL SUITES PASSED" || echo "SOME SUITES FAILED"
exit $failed
