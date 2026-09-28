#!/bin/bash
# Runs the whole test suite against a throwaway copy of Clipnik, never against your own.
#   tools/test-sandbox.sh                 (from Git Bash; takes several minutes and needs an idle desktop)
#   tools/test-sandbox.sh e2e.ahk ...     just those tests
#   tools/test-sandbox.sh --release dist/Clipnik-1.0.zip
#                                         a first start of the release zip instead of the tests
# The copy is this working tree as it is now, committed or not, without cache/ or settings.ini, so it starts
# like a fresh install. Your Clipnik is stopped for the run and started again afterwards; your clipboard and
# login shortcut are put back. The copy is deleted when everything passed and kept for a look when not.
set -u
cd "$(dirname "$0")/.."
repo=$(pwd -W)
ahk="$repo/runtime/AutoHotkey64.exe"
ctl() { MSYS_NO_PATHCONV=1 "$ahk" /ErrorStdOut "$repo/tools/sandbox-ctl.ahk" "$@"; }
winpath() { cygpath -w "$1"; }

release=""
if [ "${1:-}" = "--release" ]; then
  release=${2:?"--release needs the zip"}
  [ -f "$release" ] || { echo "No such zip: $release"; exit 1; }
  shift 2
fi
stamp=$(date +%Y%m%d-%H%M%S)
if [ -n "$release" ]; then
  root="$TEMP/clipnik release-$stamp"   # a space in the path, as in "My Documents"
  box="$root/Clipnik"
else
  root="$TEMP/clipnik-test-$stamp"
  box="$root"
fi
state="$root.state"
mkdir -p "$state"
startup="$APPDATA/Microsoft/Windows/Start Menu/Programs/Startup"

running=$(ctl running | tr -d '\r')
if [ "$(printf '%s' "$running" | grep -c .)" -gt 1 ]; then
  echo "More than one Clipnik is running; close all but one and run again:"
  echo "$running"
  exit 1
fi
mine=${running%%$'\n'*}

if [ -n "$release" ]; then
  unzip -q "$release" -d "$root" && [ -f "$box/Clipnik.cmd" ] || { echo "could not unzip $release into $root"; exit 1; }
else
  # build the copy from a private index, so your staging area is left alone
  idx="$(git rev-parse --git-dir)/sandbox-index"
  rm -f "$idx"
  GIT_INDEX_FILE="$idx" git read-tree HEAD &&
  GIT_INDEX_FILE="$idx" git add -A 2>/dev/null &&
  GIT_INDEX_FILE="$idx" git checkout-index -a -f --prefix="$box/" || { echo "could not build the copy in $box"; rm -f "$idx"; exit 1; }
  rm -f "$idx"
  : > "$box/.clipnik-test-sandbox"
fi
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

if [ -n "$release" ]; then
  # the way a user starts it
  MSYS_NO_PATHCONV=1 powershell -NoProfile -Command "Start-Process -FilePath '$(winpath "$box")\Clipnik.cmd' -WorkingDirectory '$(winpath "$box")' -WindowStyle Hidden"
else
  MSYS_NO_PATHCONV=1 powershell -NoProfile -Command "Start-Process -FilePath '$(winpath "$box")\runtime\AutoHotkey64.exe' -ArgumentList '/ErrorStdOut','Clipnik.ahk' -WorkingDirectory '$(winpath "$box")' -RedirectStandardError '$(winpath "$state")\run.err' -RedirectStandardOutput '$(winpath "$state")\run.out'"
fi
ctl ready "$(winpath "$box")" || { cat "$state/run.err" 2>/dev/null; exit 1; }

# a first start of the release: it opened without an error box, wrote fresh settings and its database, and left
# the login shortcut alone
release_checks() {
  local rc=0 version
  check() { if [ "$1" = 0 ]; then echo "ok   $2"; else echo "FAIL $2"; rc=1; fi; }
  sleep 3
  ctl dialogs "$(winpath "$box")"; [ $? = 0 ]; check $? "no message box at first start"
  version=$(sed -n 's/^global VERSION := "\([^"]*\)".*/\1/p' "$box/Clipnik.ahk" | tr -d '\r')
  iconv -f utf-16 -t utf-8 "$box/settings.ini" 2>/dev/null | tr -d '\r' | grep -qx "Version=$version"; check $? "settings.ini written, version $version"
  [ -f "$box/cache/data.db" ]; check $? "history database created"
  for lnk in Clipnik.lnk Clipjump.lnk; do
    if [ -f "$state/$lnk" ]; then cmp -s "$state/$lnk" "$startup/$lnk"; else [ ! -e "$startup/$lnk" ]; fi
    check $? "login shortcut $lnk untouched"
  done
  return $rc
}

if [ -n "$release" ]; then
  release_checks
else
  bash "$box/tests/run-all.sh" "$@"
fi
rc=$?
restore
if [ $rc = 0 ]; then
  rm -rf "$root"
  [ $keepstate = 1 ] || rm -rf "$state"
else
  echo "Kept for a look: $(winpath "$box")"
fi
exit $rc
