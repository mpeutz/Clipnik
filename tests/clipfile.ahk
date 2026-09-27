; Verifies ClipFileRead() converts v1 (8-byte size) clip files and round-trips v2 files.
; Works on the dumps in memory and never touches the clipboard: a running Clipnik would record every write.
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
; the CF_UNICODETEXT of a v2 dump, "" when it has none
dumpText(buf) {
    pos := 0
    while (fmt := NumGet(buf, pos, "UInt")) {
        size := NumGet(buf, pos + 4, "UInt")
        if (fmt = 13)
            return StrGet(buf.Ptr + pos + 8, size // 2)
        pos += 8 + size
    }
    return ""
}
; a v2 dump holding just text, as ClipboardAll() writes one
textDump(str) {
    size := (StrLen(str) + 1) * 2
    buf := Buffer(8 + size + 4, 0)
    NumPut("UInt", 13, "UInt", size, buf)
    StrPut(str, buf.Ptr + 8, "UTF-16")
    return buf
}
seq := DllCall("GetClipboardSequenceNumber", "UInt")
; v1 file from the real cache
fx := A_ScriptDir "\fixtures\v1-text.avc"   ; written by Clipjump v1 on 64-bit AutoHotkey (8-byte size fields)
v1 := FileRead(fx, "RAW")
check(!ClipFile_IsLayout(v1, 4) && ClipFile_IsLayout(v1, 8), "fixture detected as v1 8-byte layout")
got := ClipFileRead(fx)
check(ClipFile_IsLayout(got, 4), "v1 clip is converted to the v2 layout")
check(InStr(dumpText(got), "clipflow-smoke-"), "v1 text clip loads: " SubStr(dumpText(got), 1, 30))
; v2 round trip
f := A_Temp "\cj_v2test.avc"
ClipFile_Write(f, textDump("v2 round trip ☃"))
check(ClipFile_IsLayout(FileRead(f, "RAW"), 4), "v2 file detected as 4-byte layout")
check(dumpText(ClipFileRead(f)) = "v2 round trip ☃", "v2 file round trips")
FileDelete(f)
; every v1 clip in the cache should convert without error
n := 0, bad := 0
loop files "cache\clips\*.avc" {
    try ClipFileRead(A_LoopFileFullPath), n++
    catch
        bad++
}
check(bad = 0, n " cache clips convert, " bad " failed")
check(DllCall("GetClipboardSequenceNumber", "UInt") = seq, "the clipboard was never written")
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
