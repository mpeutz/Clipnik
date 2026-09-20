; helper: asks a running Clipjump to exit through its own tray action, so OnExit saves settings
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
cj := Clipjump()
cj.runFunction("exitClipjump()")
ExitApp 0
