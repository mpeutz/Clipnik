; Starting Clipnik must leave the clipboard as it was. It used to empty it (a v1 leftover) and then load every
; clip through it, leaving whichever clip loaded last. Restarts the sandbox's Clipnik the way a login would.
;   run through tools/test-sandbox.sh
#Requires AutoHotkey v2.0
#Include lib\sandbox_guard.ahk   ; drives a running Clipnik: only ever a sandbox copy's
#Include ..\publicAPI.ahk
fails := 0
check(cond, msg) {
	global fails
	FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
	if !cond
		fails++
}
DetectHiddenWindows true
SetTitleMatchMode 2
hw := WinExist("Clipnik.ahk ahk_class AutoHotkey")
RegExMatch(WinGetTitle(hw), "i)^(.*\Clipnik\.ahk) - AutoHotkey", &m)
script := m[1], exe := WinGetProcessPath(hw), pid := WinGetPID(hw)
SplitPath(script, , &dir)

; a clip in the channel, so there is something to load, and a different text on the clipboard
cj := Clipnik()
A_Clipboard := "startup-clip-" A_TickCount
Sleep 800
marker := "startup-keeps-" A_TickCount
cj.runFunction("API.blockMonitoring(1)")
A_Clipboard := marker
Sleep 300
cj.runFunction("API.blockMonitoring(0)")

PostMessage(0x111, 65405, 0, , hw)   ; the tray menu's Exit command
check(!ProcessWaitClose(pid, 30), "Clipnik exited")
ComObject("Shell.Application").ShellExecute(exe, '"' script '"', dir)   ; not Run: no inherited output pipe
ready := false
loop 60 {
	Sleep 500
	if WinExist("Clipnik.ahk ahk_class AutoHotkey") {
		try ready := (Clipnik()["startUpComplete"] = 1)
		if ready
			break
	}
}
check(ready, "Clipnik started again")
check(A_Clipboard == marker, "the clipboard is what it was before the start [" SubStr(A_Clipboard, 1, 40) "]")
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
