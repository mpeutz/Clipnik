; Channel Organizer (WebView2): opens the window, selects the first clip, creates a clip with Ctrl+N through the
; native dialog, checks it is listed, deletes it again with Del, then closes with Esc. Needs an idle desktop.
#Requires AutoHotkey v2.0
#Include lib\sandbox_guard.ahk   ; drives a running Clipnik: only ever a sandbox copy's
#Include ..\publicAPI.ahk
#Include ..\lib\gdiplus.ahk
#Include lib\gdiplus_test.ahk
SendLevel 1
SetTitleMatchMode 1
cj := Clipnik()
; keep the channel well below its clip limit: a clip past the limit compacts the oldest away and renumbers
; the rest, so a count taken before a copy no longer matches after it (earlier suites fill the channel)
if (Integer(cj.runFunction("API.getChStrength(0)")) >= Integer(cj["TOTALCLIPS"]) - 6)
	cj.runFunction("compacter()")
title := cj["TXT.ORG__name"] " ahk_class AutoHotkeyGUI"
logFile := A_Temp "\Clipnik\webhost.log"
fails := 0
check(name, cond) {
	global fails
	FileAppend((cond ? "PASS " : "FAIL ") name "`n", "*")
	if !cond
		fails++
}
; the host appends to this file constantly; a read that collides with a write must not take the suite down
readLog() {
	global logFile
	try
		return FileExist(logFile) ? FileRead(logFile) : ""
	catch
		return ""
}
snap(name) {
	global title
	WinGetPos(&x, &y, &w, &h, title)
	p := Gdip_Startup(), b := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
	Gdip_SaveBitmapToFile(b, A_ScriptDir "\out\organizer-" name ".png"), Gdip_DisposeImage(b), Gdip_Shutdown(p)
}
; the preview step needs a clip to select: a fresh copy starts with none
if (Integer(cj.runFunction("API.getChStrength(0)")) = 0) {
	A_Clipboard := "organizer-seed-" A_TickCount
	t := A_TickCount
	while (Integer(cj.runFunction("API.getChStrength(0)")) = 0 && A_TickCount - t < 3000)
		Sleep 100
}
before := Integer(cj.runFunction("API.getChStrength(0)"))
try FileDelete(logFile)
cj.runLabel("channelOrganizer")
check("window opens", WinWait(title, , 8) != 0)
WinActivate(title)
Sleep 2500
check("channels sent to the page", InStr(readLog(), '"cmd":"channels"'))
check("clips sent to the page", InStr(readLog(), '"cmd":"clips"'))
Send("{Down}")
Sleep 600
check("clip preview requested", InStr(readLog(), '"cmd":"clip"'))
snap("selected")
marker := "organizer-flow-" A_TickCount
Send("^n")
dlg := WinWait("Create New Clip ahk_class AutoHotkeyGUI", , 5)
check("new clip dialog opens", dlg != 0)
if dlg {
	ControlSetText(marker, "Edit1", "ahk_id " dlg)
	Sleep 200
	seq := DllCall("GetClipboardSequenceNumber", "UInt")
	ControlClick("OK", "ahk_id " dlg)
	t := A_TickCount
	while (Integer(cj.runFunction("API.getChStrength(0)")) != before + 1 && A_TickCount - t < 4000)
		Sleep 100
	FileAppend("     .. the new clip was in the channel " (A_TickCount - t) " ms after OK`n", "*")
	; the clip is made from the text: the user's clipboard is neither replaced nor rewritten on the way
	check("a new clip leaves the clipboard alone", DllCall("GetClipboardSequenceNumber", "UInt") = seq)
}
check("clip added to channel 0", Integer(cj.runFunction("API.getChStrength(0)")) = before + 1)
check("page received the new list", InStr(readLog(), marker))
WinActivate(title)
Sleep 300
Send("{Home}")
Sleep 500
Send("{Delete}")
Sleep 1200
check("clip deleted again", Integer(cj.runFunction("API.getChStrength(0)")) = before)
snap("after")
Send("{Esc}")
Sleep 800
check("Esc closes the window", !WinExist(title))
FileAppend((fails ? "FAILED " fails : "ALL PASSED") "`n", "*")
ExitApp fails
