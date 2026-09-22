; helper: asks a running Clipnik to exit through its own tray action, so OnExit saves settings
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
cj := Clipnik()
cj.runFunction("exitClipjump()")
ExitApp 0
