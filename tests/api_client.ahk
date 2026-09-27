; External-process check of publicAPI.ahk against a running Clipnik (v2).
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\api_client.ahk
#Requires AutoHotkey v2.0
#Include lib\sandbox_guard.ahk   ; drives a running Clipnik: only ever a sandbox copy's
#Include ..\publicAPI.ahk
out := ""
cj := Clipnik()
out .= "version=" cj.version "`n"
out .= "PROGNAME=" cj["PROGNAME"] "`n"
out .= "clip1 loc=" cj.getClipLoc(0, 1) "`n"
out .= "clip1 text=" SubStr(StrReplace(cj.getClipAt(0, 1), "`n", " "), 1, 60) "`n"
out .= "CN.Total=" cj["CN.Total"] "`n"
out .= "getChStrength(0)=" cj.runFunction("API.getChStrength(0)") "`n"
FileAppend(out, "*")
ExitApp
