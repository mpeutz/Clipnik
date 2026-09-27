; The guard that keeps the interactive tests away from a real Clipnik. Standalone: works on temp folders and path
; strings, never looks at what is running.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\sandbox_guard.ahk
#Requires AutoHotkey v2.0
#Warn All, Off
#Include lib\sandbox_guard_fns.ahk

OnError(fatal)
fatal(e, mode) {
	FileAppend("FAIL unhandled: " e.Message " (" e.What ", line " e.Line ")`n", "*")
	ExitApp 1
}

fails := 0
check(cond, msg) {
	global fails
	FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
	if !cond
		fails++
}

box := A_Temp "\cnk-guard-test-" A_TickCount
real := A_Temp "\cnk-guard-real-" A_TickCount
DirCreate(box), DirCreate(real)

; not a sandbox: whatever is running, the answer is no
p := SandboxGuard_Problem(box, [box "\Clipnik.ahk"])
check(InStr(p, "sandbox"), "a folder without the marker is refused: " p)

FileAppend("", box "\.clipnik-test-sandbox")
check(SandboxGuard_Problem(box, [box "\Clipnik.ahk"]) = "", "the sandbox's own Clipnik is allowed")
p := SandboxGuard_Problem(box, [])
check(InStr(p, "no Clipnik"), "nothing running is refused: " p)
p := SandboxGuard_Problem(box, [box "\Clipnik.ahk", real "\Clipnik.ahk"])
check(InStr(p, "2 copies"), "a second Clipnik beside the copy is refused, it might be the one the test reaches: " p)
p := SandboxGuard_Problem(box, [real "\Clipnik.ahk"])
check(InStr(p, "not this sandbox"), "a Clipnik from another folder is refused: " p)
p := SandboxGuard_Problem(box, [box "\Other.ahk"])
check(InStr(p, "not this sandbox"), "another script in the sandbox folder is not its Clipnik: " p)

; the same folder written two ways (8.3 short name vs long name, or different case) is still the same folder
long := Buffer(65536), n := DllCall("GetLongPathNameW", "Str", box, "Ptr", long, "UInt", 32768, "UInt")
longBox := n ? StrGet(long) : box
check(SandboxGuard_Problem(box, [StrUpper(longBox) "\Clipnik.ahk"]) = "", "short and long forms of the sandbox path match (" box " / " longBox ")")

DirDelete(box, true), DirDelete(real, true)
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
