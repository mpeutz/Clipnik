; ClipFile_SameContent: two clip dumps are the same capture when every format that carries content matches,
; whatever OLE's per-write bookkeeping says. Standalone: works on buffers built in memory and reads the cache
; read-only. It never touches the clipboard, so a running Clipnik records nothing.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\clipdump.ahk
#Requires AutoHotkey v2.0
#Include ..\lib\v2compat.ahk
SetWorkingDir A_ScriptDir "\.."
global STORE := Map(), CJGUI := Map()

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

CF_DIB := 8, CF_HDROP := 15
DataObject := DllCall("RegisterClipboardFormat", "Str", "DataObject", "UInt")
OlePrivate := DllCall("RegisterClipboardFormat", "Str", "Ole Private Data", "UInt")
PNG := DllCall("RegisterClipboardFormat", "Str", "PNG", "UInt")

; a v2 clip dump (format 4, size 4, data) built from [format, size, seed] blocks, the data derived from the seed
dump(blocks*) {
	total := 4
	for b in blocks
		total += 8 + b[2]
	buf := Buffer(total, 0), pos := 0
	for b in blocks {
		NumPut("UInt", b[1], "UInt", b[2], buf, pos), pos += 8
		loop b[2]
			NumPut("UChar", Mod(b[3] * 31 + A_Index * 7, 256), buf, pos + A_Index - 1)
		pos += b[2]
	}
	return buf
}

; the shape the Snipping Tool writes
snip(dibSeed, handle, private := 312) => dump([DataObject, 8, handle], [PNG, 64, dibSeed], [OlePrivate, private, 5], [CF_DIB, 256, dibSeed])

check(ClipFile_SameContent(snip(2, 3), snip(2, 3)), "identical dumps are the same")
check(ClipFile_SameContent(snip(2, 3), snip(2, 99)), "same image, new DataObject handle: the same capture")
check(ClipFile_SameContent(snip(2, 3, 312), snip(2, 3, 200)), "same image, different Ole Private Data: the same capture")
check(ClipFile_SameContent(snip(2, 3), dump([PNG, 64, 2], [CF_DIB, 256, 2])), "bookkeeping present in one dump only: the same capture")
check(!ClipFile_SameContent(snip(2, 3), snip(4, 3)), "different image, same handle: different captures")
check(!ClipFile_SameContent(snip(2, 3), dump([DataObject, 8, 3], [PNG, 64, 2], [OlePrivate, 312, 5], [CF_DIB, 256, 2], [CF_HDROP, 40, 7])),
	"an extra content format (a saved file's path): different captures")
check(!ClipFile_SameContent(dump([CF_DIB, 256, 2]), Buffer(10, 0)), "a dump that does not parse is never called the same")

; the real thing: adjacent image clips in the cache. Whether two are the same image is judged independently here,
; on their CF_DIB blocks alone, and ClipFile_SameContent has to agree
dibOf(buf) {
	pos := 0
	while (pos + 8 <= buf.Size) {
		fmt := NumGet(buf, pos, "UInt")
		if !fmt
			break
		size := NumGet(buf, pos + 4, "UInt")
		if (fmt = 8)
			return {ptr: buf.Ptr + pos + 8, size: size}
		pos += 8 + size
	}
	return ""
}
sameDib(a, b) {
	da := dibOf(a), db := dibOf(b)
	return da && db && da.size = db.size && DllCall("ntdll\RtlCompareMemory", "Ptr", da.ptr, "Ptr", db.ptr, "UPtr", da.size, "UPtr") = da.size
}
pairs := 0, agree := 0
for dir in ["cache\clips", "cache\clips1", "cache\clips2"] {
	loop files dir "\*.avc" {
		n := Integer(SubStr(A_LoopFileName, 1, -4))
		next := dir "\" (n + 1) ".avc"
		if !FileExist(next)
			continue
		a := FileRead(A_LoopFileFullPath, "RAW"), b := FileRead(next, "RAW")
		if !ClipFile_IsLayout(a, 4) || !ClipFile_IsLayout(b, 4) || !dibOf(a) || !dibOf(b)
			continue
		pairs++
		agree += (ClipFile_SameContent(a, b) = sameDib(a, b))
	}
}
check(agree = pairs, "real image pairs in the cache: " agree " of " pairs " judged the same way as their CF_DIB blocks")

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
