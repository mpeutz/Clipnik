; Clipboard History (WebView2): opens the window, selects the newest clip with the keyboard, checks the preview
; request, copies it with Ctrl+C and compares the clipboard, filters with a search, then closes with Esc.
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
#Include ..\lib\vendor\Gdip_All.ahk
SendLevel 1
SetTitleMatchMode 1
cj := Clipjump()
title := "Clipjump Clipboard History ahk_class AutoHotkeyGUI"
logFile := A_Temp "\Clipjump\webhost.log"
fails := 0
check(name, cond) {
	global fails
	FileAppend((cond ? "PASS " : "FAIL ") name "`n", "*")
	if !cond
		fails++
}
snap(name) {
	global title
	WinGetPos(&x, &y, &w, &h, title)
	p := Gdip_Startup(), b := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
	Gdip_SaveBitmapToFile(b, A_ScriptDir "\out\history-" name ".png"), Gdip_DisposeImage(b), Gdip_Shutdown(p)
}
; wait for Clipjump to record each seed clip instead of sleeping: a copy that is replaced before the copy
; path finishes never reaches history, and the row the test then selects is somebody else's clip
waitClip(needle) {
	global cj
	t := A_TickCount
	loop {
		if InStr(cj.getClipAt(0, 1), needle)
			return true
		if (A_TickCount - t > 8000)
			return false
		Sleep 150
	}
}
marker := "history-flow-" A_TickCount
A_Clipboard := marker
check("marker clip recorded", waitClip(marker))
Sleep 400
second := "second-" A_TickCount
A_Clipboard := second
check("second clip recorded", waitClip(second))
Sleep 400
try FileDelete(logFile)
cj.runLabel("history")
check("window opens", WinWait(title, , 8) != 0)
WinActivate(title)
Sleep 2500
; the host appends to this file constantly; a read that collides with a write must not take the suite down
readLog() {
	global logFile
	try
		return FileExist(logFile) ? FileRead(logFile) : ""
	catch
		return ""
}
; the window is only hidden between runs, so showing it again means waiting for the page to answer rather
; than assuming a fixed sleep covered it
waitFor(needle, ms := 8000) {
	t := A_TickCount
	loop {
		if InStr(readLog(), needle)
			return true
		if (A_TickCount - t > ms)
			return false
		Sleep 150
	}
}
check("list sent to the page", waitFor('"cmd":"list"'))
check("kinds sent to the page", waitFor('"cmd":"kinds"'))
check("rows carry a kind", InStr(readLog(), '"kind":"text"') || InStr(readLog(), '"kind":"'))
; Which row the marker lands on depends on how quickly Clipjump commits each copy to history, so the list is
; narrowed to the marker with the search box rather than walking a fixed number of rows. The retry covers a
; history insert that has not committed yet when the first search runs; ArrowDown moves focus out of the
; search box (select() focuses the table), so Ctrl+C afterwards still reaches the list.
lastPreview() {
	last := ""
	for line in StrSplit(readLog(), "`n", "`r")
		if InStr(line, '"cmd":"preview"')
			last := line
	return last
}
reached := false
loop 3 {
	Send("^f")
	Sleep 300
	Send("^a")
	Send(marker)
	Sleep 900
	Send("{Down}")
	t := A_TickCount			; the preview is a round trip through the page and the log is written after it lands
	while (!InStr(lastPreview(), marker) && A_TickCount - t < 4000)
		Sleep 150
	if InStr(lastPreview(), marker) {
		reached := true
		break
	}
}
check("search sent to host", InStr(readLog(), '"q":"' marker '"'))
check("preview requested", InStr(readLog(), '"cmd":"preview"'))
check("keyboard selection reached the marker clip", reached)
snap("selected")
A_Clipboard := ""
SendEvent("{Ctrl down}c")
Sleep 300
SendEvent("{Ctrl up}")
Sleep 800
check("Ctrl+C copied the selected clip", InStr(A_Clipboard, marker))
snap("search")
Send("^f")					; back in the search box, where the first Esc clears the filter and the second closes
Sleep 300
Send("{Esc}")
Sleep 400
check("first Esc left the window open", WinExist(title) != 0)
Send("{Esc}")
Sleep 800
check("Esc closes the window", !WinExist(title))
FileAppend((fails ? "FAILED " fails : "ALL PASSED") "`n", "*")
ExitApp fails
