; Verifies ClipFileRead() converts v1 (8-byte size) clip files and round-trips v2 files.
#Requires AutoHotkey v2.0
#Include ..\lib\v2compat.ahk
SetWorkingDir A_ScriptDir "\.."
global STORE := Map(), CJGUI := Map()
fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
backup := ClipboardAll()
; v1 file from the real cache
fx := A_ScriptDir "\fixtures\v1-text.avc"   ; written by Clipjump v1 on 64-bit AutoHotkey (8-byte size fields)
v1 := FileRead(fx, "RAW")
check(!ClipFile_IsLayout(v1, 4) && ClipFile_IsLayout(v1, 8), "fixture detected as v1 8-byte layout")
A_Clipboard := ClipFileRead(fx)
Sleep 50
check(InStr(A_Clipboard, "clipflow-smoke-"), "v1 text clip loads: " SubStr(A_Clipboard, 1, 30))
; v2 round trip
A_Clipboard := "v2 round trip ☃"
Sleep 50
f := A_Temp "\cj_v2test.avc"
try FileDelete(f)
FileAppend(ClipboardAll(), f)
v2 := FileRead(f, "RAW")
check(ClipFile_IsLayout(v2, 4), "v2 file detected as 4-byte layout")
A_Clipboard := ""
A_Clipboard := ClipFileRead(f)
Sleep 50
check(A_Clipboard = "v2 round trip ☃", "v2 file round trips")
FileDelete(f)
; every v1 clip in the cache should convert without error
n := 0, bad := 0
loop files "cache\clips\*.avc" {
    try ClipFileRead(A_LoopFileFullPath), n++
    catch
        bad++
}
check(bad = 0, n " cache clips convert, " bad " failed")
A_Clipboard := backup
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
