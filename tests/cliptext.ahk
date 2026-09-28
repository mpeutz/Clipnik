; ClipFile_TextOf() reads a clip file's text the way A_Clipboard would show it once the clip is on the clipboard,
; without putting it there: startup reads every clip this way. Standalone: builds dumps in memory and in a temp
; folder, never touches the clipboard.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\cliptext.ahk
#Requires AutoHotkey v2.0
#Include ..\lib\v2compat.ahk
SetWorkingDir A_ScriptDir "\.."
global STORE := Map(), CJGUI := Map()
OnError((e, *) => (FileAppend("FAIL unhandled: " e.Message " (" e.What ", line " e.Line ")`n", "*"), ExitApp(1)))
fails := 0
check(cond, msg) {
	global fails
	FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
	if !cond
		fails++
}

; a v2 dump from [format, Buffer] pairs, as ClipboardAll() writes one
dump(blocks*) {
	size := 4
	for b in blocks
		size += 8 + b[2].Size
	buf := Buffer(size, 0), pos := 0
	for b in blocks {
		NumPut("UInt", b[1], "UInt", b[2].Size, buf, pos)
		DllCall("RtlMoveMemory", "Ptr", buf.Ptr + pos + 8, "Ptr", b[2].Ptr, "UPtr", b[2].Size)
		pos += 8 + b[2].Size
	}
	return buf
}
str(s, enc) {
	b := Buffer(StrPut(s, enc) * (enc = "UTF-16" ? 2 : 1), 0)
	StrPut(s, b, enc)
	return b
}
; CF_HDROP: a DROPFILES header (pFiles = 20, fWide = 1) and a double-null-terminated list
hdrop(files*) {
	list := ""
	for f in files
		list .= f Chr(0)
	b := Buffer(20 + (StrLen(list) + 1) * 2, 0)
	NumPut("UInt", 20, b, 0), NumPut("Int", 1, b, 16)
	StrPut(list, b.Ptr + 20, StrLen(list), "UTF-16")
	return b
}
dir := A_Temp "\cnk-cliptext-" A_TickCount
DirCreate(dir)
textOf(buf) {
	global dir
	f := dir "\c.avc"
	ClipFile_Write(f, buf)
	return ClipFile_TextOf(f)
}

check(textOf(dump([13, str("héllo ☃`r`nline 2", "UTF-16")])) = "héllo ☃`r`nline 2", "Unicode text")
check(textOf(dump([1, str("plain ansi", "CP0")])) = "plain ansi", "ANSI text alone (CF_TEXT)")
check(textOf(dump([7, str("oem text", "CP437")])) = "oem text", "OEM text alone (CF_OEMTEXT)")
check(textOf(dump([13, str("unicode wins", "UTF-16")], [1, str("ansi loses", "CP0")])) = "unicode wins", "Unicode is preferred over ANSI")
check(textOf(dump([15, hdrop("C:\a.txt", "D:\b c\d.png")])) = "C:\a.txt`r`nD:\b c\d.png", "a file list gives the paths, one per line")
check(textOf(dump([15, hdrop("C:\a.txt")], [13, str("name text", "UTF-16")])) = "name text", "text is preferred over files, as A_Clipboard does")
dib := Buffer(40 + 16, 0), NumPut("UInt", 40, "Int", 2, "Int", 2, "UShort", 1, "UShort", 32, dib)
; a damaged file list without its terminating zeros must stop at its own block, not run on into the next one (or
; off the end of the file): startup reads every clip this way, and a crash there would stop Clipnik starting
cut := Buffer(20 + 16, 0), NumPut("UInt", 20, cut, 0), NumPut("Int", 1, cut, 16), StrPut("C:\a.txt", cut.Ptr + 20, 8, "UTF-16")
check(textOf(dump([15, cut], [8, dib])) = "C:\a.txt", "a file list without its terminating zeros stops at its block")
check(textOf(dump([8, dib])) = "", "an image alone has no text")
check(textOf(dump([8, dib], [13, str("caption", "UTF-16")])) = "caption", "an image with text gives the text")
; older caches hold dumps with a second one appended (FileAppend added instead of replacing); ClipboardAll() reads
; up to the first terminator, so the first dump is the clip
one := dump([13, str("first dump", "UTF-16")]), two := dump([13, str("second dump", "UTF-16")])
both := Buffer(one.Size + two.Size)
DllCall("RtlMoveMemory", "Ptr", both.Ptr, "Ptr", one.Ptr, "UPtr", one.Size)
DllCall("RtlMoveMemory", "Ptr", both.Ptr + one.Size, "Ptr", two.Ptr, "UPtr", two.Size)
check(textOf(both) = "first dump", "a dump with another appended reads the first, as ClipboardAll does")
check(ClipFile_TextOf(A_ScriptDir "\fixtures\v1-text.avc") ~= "^clipflow-smoke-", "a v1 (8-byte size) clip file is read too")
check(ClipFile_TextOf(dir "\missing.avc") = "", "a missing file gives no text")
ClipFile_Write(dir "\made.avc", ClipFile_FromText("made ☃`r`nfrom text"))
check(ClipFile_TextOf(dir "\made.avc") = "made ☃`r`nfrom text", "a dump made from text reads back as that text")
check(ClipFile_IsLayout(FileRead(dir "\made.avc", "RAW"), 4), "a dump made from text is a v2 clip file")
FileAppend("garbage", dir "\bad.avc")
check(ClipFile_TextOf(dir "\bad.avc") = "", "a file that is not a dump gives no text")
DirDelete(dir, true)

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
