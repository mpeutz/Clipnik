#!/bin/bash
# Runs the whole test suite against a throwaway copy of Clipnik, never against your own.
#   tools/test-sandbox.sh                 (from Git Bash; takes several minutes and needs an idle desktop)
#   tools/test-sandbox.sh e2e.ahk ...     just those tests
# The copy is this working tree as it is now, committed or not, without cache/ or settings.ini, so it starts
# like a fresh install. Your Clipnik is stopped for the run and started again afterwards; your clipboard and
# login shortcut are put back. The copy is deleted when everything passed and kept for a look when not.
set -u
cd "$(dirname "$0")/.."
repo=$(pwd -W)
ahk="$repo/runtime/AutoHotkey64.exe"
ctl() { MSYS_NO_PATHCONV=1 "$ahk" /ErrorStdOut "$repo/tools/sandbox-ctl.ahk" "$@"; }
winpath() { cygpath -w "$1"; }

box="$TEMP/clipnik-test-$(date +%Y%m%d-%H%M%S)"
state="$box.state"
mkdir -p "$state"
startup="$APPDATA/Microsoft/Windows/Start Menu/Programs/Startup"

running=$(ctl running | tr -d '\r')
if [ "$(printf '%s' "$running" | grep -c .)" -gt 1 ]; then
  echo "More than one Clipnik is running; close all but one and run again:"
  echo "$running"
  exit 1
fi
mine=${running%%$'\n'*}

# build the copy from a private index, so your staging area is left alone
idx="$(git rev-parse --git-dir)/sandbox-index"
rm -f "$idx"
GIT_INDEX_FILE="$idx" git read-tree HEAD &&
GIT_INDEX_FILE="$idx" git add -A 2>/dev/null &&
GIT_INDEX_FILE="$idx" git checkout-index -a -f --prefix="$box/" || { echo "could not build the copy in $box"; rm -f "$idx"; exit 1; }
rm -f "$idx"
: > "$box/.clipnik-test-sandbox"
echo "Sandbox: $(winpath "$box")"

# undoes only the steps that happened: the flags below are set as each one is done
restored=0 saved=0 stopped=0 keepstate=0
restore() {
  [ $restored = 1 ] && return
  restored=1
  ctl stop "$(winpath "$box")" force
  if [ $saved = 1 ]; then
    # a Clipnik still running would record the restored clipboard as a new clip
    if [ -z "$(ctl running)" ]; then
      ctl clip-restore "$(winpath "$state/clipboard.bin")"
    else
      echo "Clipboard not restored: a Clipnik is still running. It is saved in $(winpath "$state/clipboard.bin")"
      keepstate=1
    fi
    for lnk in Clipnik.lnk Clipjump.lnk; do
      rm -f "$startup/$lnk"
      [ -f "$state/$lnk" ] && cp -p "$state/$lnk" "$startup/$lnk"
    done
  fi
  if [ $stopped = 1 ]; then
    MSYS_NO_PATHCONV=1 powershell -NoProfile -Command "Start-Process -FilePath '${mine%%|*}' -ArgumentList '\"${mine#*|}\"' -WorkingDirectory (Split-Path '${mine#*|}')"
    echo "Your Clipnik is running again: ${mine#*|}"
  fi
}
trap restore EXIT INT TERM

ctl clip-save "$(winpath "$state/clipboard.bin")" || exit 1
for lnk in Clipnik.lnk Clipjump.lnk; do
  [ -f "$startup/$lnk" ] && cp -p "$startup/$lnk" "$state/$lnk"
done
saved=1
if [ -n "$mine" ]; then
  script=${mine#*|}
  echo "Stopping your Clipnik: $script"
  stopped=1   # set first, so a Ctrl+C mid-stop still restarts it; Clipnik is #SingleInstance Force, so
              # restarting one that did not stop replaces it rather than running a second copy
  ctl stop "$script" || exit 1
  [ -z "$(ctl running)" ] || { echo "A Clipnik is still running after stopping yours:"; ctl running; exit 1; }
fi

MSYS_NO_PATHCONV=1 powershell -NoProfile -Command "Start-Process -FilePath '$(winpath "$box")\runtime\AutoHotkey64.exe' -ArgumentList '/ErrorStdOut','Clipnik.ahk' -WorkingDirectory '$(winpath "$box")' -RedirectStandardError '$(winpath "$state")\run.err' -RedirectStandardOutput '$(winpath "$state")\run.out'"
ctl ready "$(winpath "$box")" || { cat "$state/run.err" 2>/dev/null; exit 1; }

bash "$box/tests/run-all.sh" "$@"
rc=$?
restore
if [ $rc = 0 ]; then
  rm -rf "$box"
  [ $keepstate = 1 ] || rm -rf "$state"
else
  echo "Kept for a look: $(winpath "$box")"
fi
exit $rc
