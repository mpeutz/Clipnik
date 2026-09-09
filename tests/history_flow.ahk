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
marker := "history-flow-" A_TickCount
A_Clipboard := marker
Sleep 600
A_Clipboard := "second-" A_TickCount
Sleep 600
try FileDelete(logFile)
cj.runLabel("history")
check("window opens", WinWait(title, , 8) != 0)
WinActivate(title)
Sleep 2500
readLog() {
	global logFile
	return FileExist(logFile) ? FileRead(logFile) : ""
}
check("list sent to the page", InStr(readLog(), '"cmd":"list"'))
Send("{Down}")
Sleep 300
Send("{Down}")
Sleep 600
txt := readLog()
check("preview requested", InStr(txt, '"cmd":"preview"'))
snap("selected")
A_Clipboard := ""
Send("^c")
Sleep 800
check("Ctrl+C copied the selected clip", InStr(A_Clipboard, marker))
Send("^f")
Sleep 200
Send("history-flow")
Sleep 800
txt := readLog()
check("search sent to host", InStr(txt, '"q":"history-flow"'))
snap("search")
Send("{Esc}")
Sleep 200
Send("{Esc}")
Sleep 800
check("Esc closes the window", !WinExist(title))
FileAppend((fails ? "FAILED " fails : "ALL PASSED") "`n", "*")
ExitApp fails
