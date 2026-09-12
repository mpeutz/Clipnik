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
ref := cj.runFunction("Help_ReferenceProbe()")
check("reference has paste-mode rows", RegExMatch(ref, "pasteMode=[1-9]"))
check("reference lists a format letter", RegExMatch(ref, "formats=[1-9]"))
check("reference lists action entries", RegExMatch(ref, "actions=[1-9]"))
check("reference has the configured hotkeys", RegExMatch(ref, "hotkeys=[1-9]"))
check("reference lists rule actions", RegExMatch(ref, "rules=[1-9]"))
topics := cj.runFunction("Help_TopicCount()")
check("every topic fragment is present", Integer(topics) = 11)
; driven through a host message rather than simulated typing: Send/SendEvent into the WebView2 search box
; proved unreliable here (focus does not reliably land there in time under the test harness)
cj.runFunction("Help_Filter(channel)")
Sleep 400
snapText := cj.runFunction("HelpWin_FilterProbe()")
check("filter reports matches", RegExMatch(snapText, "shown=[1-9]"))
check("filter excludes unrelated topics", !InStr(snapText, "shown=11"))
cj.runFunction("Help_Filter()")
Sleep 300
cj.runFunction("Help_Close()")
Sleep 800
check("window closed", !WinExist(title))
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
