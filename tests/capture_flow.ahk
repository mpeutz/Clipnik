; Clipnik blocks its own clipboard monitoring around every write it makes itself (API.blockMonitoring), and the
; unblock swallows the one notification that write causes. When the block saw no write - startup with no clips
; to load, a paste that put nothing on the clipboard - the next notification swallowed was the user's own copy:
; the first copy after a fresh start was never recorded.
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
cj := Clipnik()
strength() => Integer(cj.runFunction("API.getChStrength(0)"))
; true once the channel holds one more clip than before, within 3 s
grew(before) {
	loop 30 {
		if (strength() > before)
			return true
		Sleep 100
	}
	return false
}
stamp := "capture-" A_TickCount
added := 0

; a write while monitoring is blocked is Clipnik's own: not recorded
s := strength()
cj.runFunction("API.blockMonitoring(1)")
A_Clipboard := stamp " own"
Sleep 300
cj.runFunction("API.blockMonitoring(0)")
check(!grew(s), "a write while monitoring is blocked is not recorded")

; a block that saw no write must not swallow the copy after it
Sleep 300
s := strength()
cj.runFunction("API.blockMonitoring(1)")
cj.runFunction("API.blockMonitoring(0)")
A_Clipboard := stamp " user"
got := grew(s)
added += got
check(got && cj.getClipAt(0, 1) = stamp " user", "the first copy after an empty block is recorded [" cj.getClipAt(0, 1) "]")

; and the copy after that, as always
Sleep 300
s := strength()
A_Clipboard := stamp " next"
got := grew(s)
added += got
check(got, "the next copy is recorded too")

; remove this test's clips, newest first, only while the newest is one of them
loop added {
	if !InStr(cj.getClipAt(0, 1), stamp)
		break
	cj.runFunction("API.deleteClip(0,1)")
	Sleep 300
}
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
