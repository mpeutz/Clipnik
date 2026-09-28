; lib/gdiplus.ahk against the images the Gdip_All library it replaced produced for the same drawing, saving and
; reading (tests/fixtures/gdiplus, made on the development machine: the ring and text renders depend on its fonts).
; Standalone: draws into bitmaps and files, never touches the clipboard.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\gdiplus.ahk
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\lib\v2compat.ahk
#Include ..\lib\gdiplus.ahk
#Include ..\lib\translations.ahk
#Include ..\src\ui\native\Theme.ahk
#Include ..\src\ui\native\RingGeom.ahk
#Include ..\src\ui\native\Ring.ahk
#Include lib\gdiplus_scenarios.ahk
SetWorkingDir A_ScriptDir "\.."
FileEncoding "UTF-8"
OnError((e, *) => (FileAppend("FAIL unhandled: " e.Message " (" e.What ", line " e.Line ")`n", "*"), ExitApp(1)))
global TXT := Translations_load("languages/english.txt")
DllCall("GDI32.DLL\AddFontResourceEx", "Str", A_WorkingDir "\icons\lucide.ttf", "UInt", 0x10, "Int", 0)
fails := 0
check(cond, msg) {
	global fails
	FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
	if !cond
		fails++
}

out := A_Temp "\cnk-gdiplus-" A_TickCount
DirCreate(out)
GdipScenarios(out)
ref := A_ScriptDir "\fixtures\gdiplus"
loop files ref "\*.*" {
	if (A_LoopFileName ~= "^clip-")
		continue
	mine := out "\" A_LoopFileName
	check(FileExist(mine) && SameBytes(A_LoopFileFullPath, mine), A_LoopFileName " matches the reference")
}
DirDelete(out, true)
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails

SameBytes(a, b) {
	x := FileRead(a, "RAW"), y := FileRead(b, "RAW")
	return x.Size = y.Size && DllCall("ntdll\RtlCompareMemory", "Ptr", x, "Ptr", y, "UPtr", x.Size, "UPtr") = x.Size
}
