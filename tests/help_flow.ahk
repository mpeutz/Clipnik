; Help window (WebView2): opens from Action Mode, shows the topic list, filters, deep links, and remembers
; its geometry. Needs a running Clipnik and an idle desktop.
#Requires AutoHotkey v2.0
#Include lib\sandbox_guard.ahk   ; drives a running Clipnik: only ever a sandbox copy's
#Include ..\publicAPI.ahk
SendLevel 1
SetTitleMatchMode 1
CoordMode "Mouse", "Screen"
cj := Clipnik()
title := "Clipnik Help ahk_class AutoHotkeyGUI"
logFile := A_Temp "\Clipnik\webhost.log"
fails := 0
step(s) => FileAppend("     .. " s "`n", "*")
check(name, cond) {
	global fails
	FileAppend((cond ? "PASS " : "FAIL ") name "`n", "*")
	if !cond
		fails++
}

; poll for a condition instead of sleeping a fixed time: the Settings window build and the action
; ring's first open both vary by hundreds of milliseconds on a loaded desktop
waitUntil(cond, ms := 6000) {
	t := A_TickCount
	loop {
		if cond()
			return true
		if (A_TickCount - t > ms)
			return false
		Sleep 100
	}
}
ringOpen() {
	global cj
	return cj.runFunction("Ring_IsOpen()") = 1
}
ctlReady(winTitle, ctlText) {
	try return ControlGetHwnd(ctlText, winTitle) != 0
	return false
}
; clicks a control where it actually sits on screen. Control coordinates are relative to the window's client
; area, so the client origin is what turns them into screen coordinates.
clickControl(winTitle, ctlText) {
	if !WinExist(winTitle)
		return false
	WinActivate(winTitle)
	WinWaitActive(winTitle, , 3)
	h := 0
	try h := ControlGetHwnd(ctlText, winTitle)
	if !h
		return false
	ControlGetPos(&cx, &cy, &cw, &ch, h)
	WinGetClientPos(&wx, &wy, , , winTitle)
	prev := A_CoordModeMouse
	CoordMode "Mouse", "Screen"
	MouseMove(wx + cx + cw // 2, wy + cy + ch // 2)
	Sleep 250
	Click()
	CoordMode "Mouse", prev
	return true
}
try FileDelete(logFile)
cj.runFunction("Help_Open()")
check("window opens", WinWait(title, , 8) != 0)
WinActivate(title)
Sleep 2500
check("no error dialog", !WinExist("Clipnik.ahk ahk_class #32770"))
ref := cj.runFunction("Help_ReferenceProbe()")
check("reference has paste-mode rows", RegExMatch(ref, "pasteMode=[1-9]"))
check("reference lists a format letter", RegExMatch(ref, "formats=[1-9]"))
check("reference lists action entries", RegExMatch(ref, "actions=[1-9]"))
check("reference has the configured hotkeys", RegExMatch(ref, "hotkeys=[1-9]"))
check("reference lists rule actions", RegExMatch(ref, "rules=[1-9]"))
topics := cj.runFunction("Help_TopicCount()")
check("every topic fragment is present", Integer(topics) = 12)
; driven through a host message rather than simulated typing: Send/SendEvent into the WebView2 search box
; proved unreliable here (focus does not reliably land there in time under the test harness)
cj.runFunction("Help_Filter(channel)")
Sleep 400
snapText := cj.runFunction("HelpWin_FilterProbe()")
check("filter reports matches", RegExMatch(snapText, "shown=[1-9]"))
check("filter excludes unrelated topics", !InStr(snapText, "shown=12"))
cj.runFunction("Help_Filter()")
Sleep 300
; "slugify" lives only inside the Formats topic's generated table (the Slugify format's label), never in any
; topic's static prose or keywords, and Formats is never opened by this test: this only matches if generated
; tables are filled for every topic up front, not only for whichever topic happens to be on screen
cj.runFunction("Help_Filter(slugify)")
Sleep 400
snapText := cj.runFunction("HelpWin_FilterProbe()")
check("filter finds terms that live only in a generated table", RegExMatch(snapText, "shown=[1-9]"))
cj.runFunction("Help_Filter()")
Sleep 300

step("Action Mode F1 opens help")
cj.runFunction("Help_Close()")
Sleep 600
SendEvent("^+a")
check("action ring open", waitUntil(ringOpen))
SendEvent("{F1}")
check("F1 opened help", WinWait(title, , 8) != 0)
Sleep 1500
check("help deep-linked to the action reference", InStr(cj.runFunction("HelpWin_TopicProbe()"), "reference-actionmode"))

step("Action Mode F2 opens the paste-mode reference")
cj.runFunction("Help_Close()")
Sleep 600
SendEvent("^+a")
check("action ring open for F2", waitUntil(ringOpen))
SendEvent("{F2}")
check("F2 opened help", WinWait(title, , 8) != 0)
Sleep 1500
check("help deep-linked to the paste-mode reference", InStr(cj.runFunction("HelpWin_TopicProbe()"), "reference-pastemode"))

step("Settings' Help button opens the settings reference")
cj.runFunction("Help_Close()")
Sleep 600
settingsTitle := "Clipnik Settings ahk_class AutoHotkeyGUI"
cj.runLabel("settings")
check("settings window opens", WinWait(settingsTitle, , 5) != 0)
WinActivate(settingsTitle)
check("settings' Help button is built", waitUntil(ctlReady.Bind(settingsTitle, cj["TXT.TRY_help"])))
; a real click, not ControlClick: the themed buttons do not reliably raise their Click event from posted
; messages, and this step is meant to prove the button works the way a person uses it
clickControl(settingsTitle, cj["TXT.TRY_help"])
check("help opened from Settings", WinWait(title, , 8) != 0)
Sleep 1500
check("help deep-linked to the settings reference", InStr(cj.runFunction("HelpWin_TopicProbe()"), "reference-settings"))
cj.runFunction("Help_Close()")
Sleep 500
clickControl(settingsTitle, cj["TXT.SET_cancel"])
check("settings window closed", WinWaitClose(settingsTitle, , 5) != 0)

step("the tray card and the classic tray menu both still carry a Help entry")
epr := cj.runFunction("Help_EntryPointsProbe()")
check("tray card's Help item is a direct action: " epr, InStr(epr, "card=1"))
check("classic tray menu has a Help entry: " epr, InStr(epr, "classic=1"))

step("geometry survives a close and reopen")
cj.runFunction("Help_Open()")
check("help open for the geometry check", WinWait(title, , 8) != 0)
Sleep 500
WinMove(180, 160, 820, 560, title)
Sleep 500
WinGetPos(&sx, &sy, &sw, &sh, title)
cj.runFunction("Help_Close()")
Sleep 800
g := cj.runFunction("Help_GeometrySpec()")
check("geometry saved: " g, InStr(g, "w") && InStr(g, "h"))
cj.runFunction("Help_Open()")
check("reopens", WinWait(title, , 8) != 0)
Sleep 500
WinGetPos(&rx, &ry, &rw, &rh, title)
check("restored size " rw "x" rh " matches saved " sw "x" sh, Abs(rw - sw) <= 4 && Abs(rh - sh) <= 4)

cj.runFunction("Help_Close()")
Sleep 800
check("window closed", !WinExist(title))

step("Esc closes the window")
cj.runFunction("Help_Open()")
check("help open for the Esc test", WinWait(title, , 8) != 0)
WinActivate(title)
Sleep 500
SendEvent("{Esc}")
check("Esc closed the window", WinWaitClose(title, , 5) != 0)

step("Esc first clears an active filter, then closes on the second press")
cj.runFunction("Help_Open()")
check("help open for the two-stage Esc test", WinWait(title, , 8) != 0)
WinActivate(title)
Sleep 500
cj.runFunction("Help_Filter(channel)")
Sleep 400
snapText := cj.runFunction("HelpWin_FilterProbe()")
check("filter is active before Esc: " snapText, !InStr(snapText, "shown=12"))
SendEvent("{Esc}")
Sleep 400
check("first Esc left the window open", WinExist(title) != 0)
snapText := cj.runFunction("HelpWin_FilterProbe()")
check("first Esc cleared the filter: " snapText, InStr(snapText, "shown=12"))
SendEvent("{Esc}")
check("second Esc closed the window", WinWaitClose(title, , 5) != 0)

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
