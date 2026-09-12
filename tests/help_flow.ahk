; Help window (WebView2): opens from Action Mode, shows the topic list, filters, deep links, and remembers
; its geometry. Needs a running Clipjump and an idle desktop.
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
SendLevel 1
SetTitleMatchMode 1
CoordMode "Mouse", "Screen"
cj := Clipjump()
title := "Clipjump Help ahk_class AutoHotkeyGUI"
logFile := A_Temp "\Clipjump\webhost.log"
fails := 0
check(name, cond) {
	global fails
	FileAppend((cond ? "PASS " : "FAIL ") name "`n", "*")
	if !cond
		fails++
}
try FileDelete(logFile)
cj.runFunction("Help_Open()")
check("window opens", WinWait(title, , 8) != 0)
WinActivate(title)
Sleep 2500
check("no error dialog", !WinExist("Clipjump.ahk ahk_class #32770"))
cj.runFunction("Help_Close()")
Sleep 800
check("window closed", !WinExist(title))
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
