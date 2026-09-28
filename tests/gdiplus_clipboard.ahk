; The clipboard half of tests/gdiplus.ahk: a bitmap put on the clipboard and read back, against what the Gdip_All
; library lib/gdiplus.ahk replaced produced (tests/fixtures/gdiplus/clip-*). Writes the clipboard.
;   run through tools/test-sandbox.sh
#Requires AutoHotkey v2.0
#Warn All, Off
#Include lib\sandbox_guard.ahk   ; writes the clipboard a running Clipnik records: only ever a sandbox copy's
#Include ..\lib\gdiplus.ahk
#Include lib\gdiplus_scenarios.ahk
fails := 0
check(cond, msg) {
	global fails
	FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
	if !cond
		fails++
}
SameBytes(a, b) {
	x := FileRead(a, "RAW"), y := FileRead(b, "RAW")
	return x.Size = y.Size && DllCall("ntdll\RtlCompareMemory", "Ptr", x, "Ptr", y, "UPtr", x.Size, "UPtr") = x.Size
}

ref := A_ScriptDir "\fixtures\gdiplus"
out := A_Temp "\cnk-gdiplus-clip-" A_TickCount
DirCreate(out)
GdipClipScenarios(out, ref "\shapes.png")
loop files ref "\clip-*.*" {
	mine := out "\" A_LoopFileName
	same := FileExist(mine) && SameBytes(A_LoopFileFullPath, mine)
	shown := (!same && A_LoopFileExt = "txt" && FileExist(mine)) ? " [" StrReplace(FileRead(mine), "`n", "|") "] expected [" StrReplace(FileRead(A_LoopFileFullPath), "`n", "|") "]" : ""
	check(same, A_LoopFileName " matches the reference" shown)
}
check(FileExist(ref "\clip-set.bin"), "the clipboard references exist")
if !fails
	DirDelete(out, true)
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
