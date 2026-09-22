#!/bin/bash
# Usage: tools/validate-libs.sh lib1 lib2 ...   (names of files under lib/, without .ahk)
# Builds a throwaway include-only script and runs the v2 syntax validator on it.
# Unassigned-global warnings are expected here (the globals live in Clipnik.ahk) and are filtered out;
# anything else printed is a real problem. Exit code is the validator's.
cd "$(dirname "$0")/.."
{
  printf '%s\n' '#Requires AutoHotkey v2.0' '#Warn All, StdOut' '#Include ..\lib\v2compat.ahk'
  for f in "$@"; do printf '%s\n' '#Include ..\lib\'"$f"'.ahk'; done
  printf '%s\n' 'ExitApp'
} > tests/_v.ahk
MSYS_NO_PATHCONV=1 timeout 20 ./runtime/AutoHotkey64.exe /ErrorStdOut /validate tests/_v.ahk > tests/_v.out 2>&1
rc=$?
grep -v "appears to never be assigned\|Specifically:\|same name as a global\|^\s*$" tests/_v.out
[ $rc -eq 124 ] && { echo "TIMEOUT (dialog?)"; taskkill //F //IM AutoHotkey64.exe >/dev/null 2>&1; }
echo "exit=$rc"
exit $rc
