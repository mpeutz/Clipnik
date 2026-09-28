; Right after a copy other programs read the clipboard too (Windows' clipboard history, other managers), and
; while one holds it open nothing else can write it. A transform rule rewrites the clip through the clipboard at
; exactly that moment; it must wait its turn rather than silently leave the clip as it was.
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
	return cond
}
cj := Clipnik()
if (Integer(cj.runFunction("API.getChStrength(0)")) >= Integer(cj["TOTALCLIPS"]) - 6)
	cj.runFunction("compacter()")

; a URL clip to transform
stamp := A_TickCount, url := "https://example.com/busy" stamp
s := Integer(cj.runFunction("API.getChStrength(0)"))
Sleep 300
A_Clipboard := url
t := A_TickCount
while (cj.getClipAt(0, 1) != url && A_TickCount - t < 3000)
	Sleep 100
check(cj.getClipAt(0, 1) = url, "the URL was recorded")
Sleep 500

; another program holds the clipboard open for 400 ms
flag := A_Temp "\cnk-busy-" stamp ".flag"
helper := A_Temp "\cnk-busy-" stamp ".ahk"
FileAppend('#NoTrayIcon`nwhile !DllCall("OpenClipboard", "Ptr", 0)`n`tSleep 5`nFileAppend("", "' flag '")`nSleep 400`nDllCall("CloseClipboard")`n', helper)
Run('"' A_AhkPath '" "' helper '"')
t := A_TickCount
while !FileExist(flag) && A_TickCount - t < 3000
	Sleep 10
check(FileExist(flag), "the other program holds the clipboard")

; the transform arrives while it does
cj.runFunction("Rules_ApplyTransform(" cj["TXT.TRF_markdownLink"] ")")
Sleep 800
got := cj.getClipAt(0, 1)
check(SubStr(got, 1, 1) = "[" && InStr(got, "busy" stamp), "the transform waited for the clipboard and rewrote the clip [" got "]")

try FileDelete(flag)
try FileDelete(helper)
if InStr(cj.getClipAt(0, 1), "busy" stamp)
	cj.runFunction("API.deleteClip(0,1)")

; held longer than the transform waits: it gives up, the clip stays as it was, and it does not then spend
; another second waiting for the notification of a write that never happened, with copies going unrecorded
url := "https://example.com/stuck" stamp
Sleep 300
A_Clipboard := url
t := A_TickCount
while (cj.getClipAt(0, 1) != url && A_TickCount - t < 3000)
	Sleep 100
check(cj.getClipAt(0, 1) = url, "the second URL was recorded")
Sleep 500
flag := A_Temp "\cnk-stuck-" stamp ".flag", helper := A_Temp "\cnk-stuck-" stamp ".ahk"
FileAppend('#NoTrayIcon`nwhile !DllCall("OpenClipboard", "Ptr", 0)`n`tSleep 5`nFileAppend("", "' flag '")`nSleep 1500`nDllCall("CloseClipboard")`n', helper)
Run('"' A_AhkPath '" "' helper '"')
t := A_TickCount
while !FileExist(flag) && A_TickCount - t < 3000
	Sleep 10
t := A_TickCount
cj.runFunction("Rules_ApplyTransform(" cj["TXT.TRF_markdownLink"] ")")
took := A_TickCount - t
check(took < 1600, "a transform that could not write gave up after its own wait (" took " ms)")
Sleep 700   ; the other program lets go
check(cj.getClipAt(0, 1) = url, "the clip it could not rewrite is kept as it was [" cj.getClipAt(0, 1) "]")
after := "after-stuck-" stamp
A_Clipboard := after
t := A_TickCount
while (cj.getClipAt(0, 1) != after && A_TickCount - t < 3000)
	Sleep 100
check(cj.getClipAt(0, 1) = after, "the next copy is recorded")
try FileDelete(flag)
try FileDelete(helper)
loop 2
	if InStr(cj.getClipAt(0, 1), stamp)
		cj.runFunction("API.deleteClip(0,1)")
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
