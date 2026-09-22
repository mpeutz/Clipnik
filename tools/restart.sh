#!/bin/bash
# Restarts Clipnik on the v2 runtime (SingleInstance Force replaces the running one), waits, reports errors and dialogs.
cd "$(dirname "$0")/.."
mkdir -p "$TMP/cj"
MSYS_NO_PATHCONV=1 powershell -NoProfile -Command "Start-Process -FilePath '.\runtime\AutoHotkey64.exe' -ArgumentList '/ErrorStdOut','Clipnik.ahk' -RedirectStandardError \"\$env:TMP\cj\run.err\" -RedirectStandardOutput \"\$env:TMP\cj\run.out\"" 
sleep ${1:-6}
cat "$TMP/cj/run.err" "$TMP/cj/run.out" 2>/dev/null
tasklist | grep -ci autohotkey64 | sed 's/^/instances=/'
powershell -NoProfile -File tools/dialogs.ps1 2>&1 | head -20
