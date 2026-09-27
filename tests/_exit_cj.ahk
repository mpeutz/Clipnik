; helper: asks a running Clipnik to exit through its own tray action, so OnExit saves settings
#Requires AutoHotkey v2.0
#Include lib\sandbox_guard.ahk   ; drives a running Clipnik: only ever a sandbox copy's
#Include ..\publicAPI.ahk
cj := Clipnik()
cj.runFunction("exitClipjump()")
ExitApp 0
