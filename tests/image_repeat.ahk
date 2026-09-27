; A snipping tool writes the same image to the clipboard twice within a moment: Clipnik must record it once,
; while two deliberate copies (Ctrl+C in between) are both kept. Needs a running Clipnik and an idle desktop.
;
; The Snipping Tool writes through OLE, and OLE puts a DataObject format on the clipboard beside the image: an
; 8-byte handle that is different on every write. The two writes are the same image and still not the same
; bytes, so putImageOle writes exactly that shape. A plain SetClipboardData writer never produces it.
;
; This runs against the user's live Clipnik, so it must never cost them anything:
;   - it refuses to run when the channel is near its limit, because a clip past the limit makes compacter()
;     delete the oldest clips for good; it never compacts on its own
;   - it removes only clips it can prove are its own: 140x70 test images, by the size of their dump
;   - it deletes only the history rows and JPEGs it created, never by a size heuristic alone
#Requires AutoHotkey v2.0
#Include lib\sandbox_guard.ahk   ; drives a running Clipnik: only ever a sandbox copy's
#Include ..\publicAPI.ahk
#Include ..\lib\vendor\Gdip_All.ahk
SendLevel 1
cj := Clipnik()
fails := 0
check(name, cond) {
	global fails
	FileAppend((cond ? "PASS " : "FAIL ") name "`n", "*")
	if !cond
		fails++
}
strength() => Integer(cj.runFunction("API.getChStrength(0)"))

; the most clips this test can add (all four scenarios recording every write), plus a margin
MAX_ADDED := 8
limit := Integer(cj["TOTALCLIPS"])
if (strength() + MAX_ADDED >= limit) {
	FileAppend("FAIL not run: the Default channel holds " strength() " of " limit " clips, and adding up to " MAX_ADDED
		. " would make Clipnik delete the oldest ones. Free some clips or raise the limit, then run again.`n", "*")
	ExitApp 1
}

; what exists before the test, so its cleanup can name exactly what it created
histBefore := Integer(cj.runFunction("History_NewestId()"))
histDir := A_ScriptDir "\..\cache\history\"
jpgsBefore := Map()
loop files histDir "*.jpg"
	jpgsBefore[A_LoopFileName] := true

newBitmap(color) {
	pBitmap := Gdip_CreateBitmap(140, 70)
	G := Gdip_GraphicsFromImage(pBitmap)
	pBrush := Gdip_BrushCreateSolid(color)
	Gdip_FillRectangle(G, pBrush, 0, 0, 140, 70)
	Gdip_DeleteBrush(pBrush), Gdip_DeleteGraphics(G)
	return pBitmap
}

; a plain writer: CF_DIB alone, so two writes of one image are byte-identical
putImage(color) {
	pBitmap := newBitmap(color)
	Gdip_SetBitmapToClipboard(pBitmap)
	Gdip_DisposeImage(pBitmap)
}

; an OLE writer, as the Snipping Tool is: the same CF_DIB plus a DataObject handle that changes every write,
; all in one clipboard session so it is one clipboard change, not two
putImageOle(color) {
	static DataObject := DllCall("RegisterClipboardFormat", "Str", "DataObject", "UInt")
	pBitmap := newBitmap(color)
	off1 := A_PtrSize = 8 ? 52 : 44, off2 := A_PtrSize = 8 ? 32 : 24
	hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap)
	oi := Buffer(A_PtrSize = 8 ? 104 : 84, 0)
	DllCall("GetObject", "Ptr", hBitmap, "Int", oi.Size, "Ptr", oi.Ptr)
	hdib := DllCall("GlobalAlloc", "UInt", 2, "UPtr", 40 + NumGet(oi, off1, "UInt"), "Ptr")
	pdib := DllCall("GlobalLock", "Ptr", hdib, "Ptr")
	DllCall("RtlMoveMemory", "Ptr", pdib, "Ptr", oi.Ptr + off2, "UPtr", 40)
	DllCall("RtlMoveMemory", "Ptr", pdib + 40, "Ptr", NumGet(oi, off2 - A_PtrSize, "UPtr"), "UPtr", NumGet(oi, off1, "UInt"))
	DllCall("GlobalUnlock", "Ptr", hdib)
	DllCall("DeleteObject", "Ptr", hBitmap)
	Gdip_DisposeImage(pBitmap)
	hdo := DllCall("GlobalAlloc", "UInt", 2, "UPtr", 8, "Ptr")
	pdo := DllCall("GlobalLock", "Ptr", hdo, "Ptr")
	NumPut("UInt", Random(1, 0x7FFFFFFF), "UInt", Random(1, 0x7FFFFFFF), pdo)
	DllCall("GlobalUnlock", "Ptr", hdo)
	DllCall("OpenClipboard", "Ptr", 0)
	DllCall("EmptyClipboard")
	DllCall("SetClipboardData", "UInt", 8, "Ptr", hdib)
	DllCall("SetClipboardData", "UInt", DataObject, "Ptr", hdo)
	DllCall("CloseClipboard")
}

; every scenario is judged on the clips it added itself, so one failure does not cascade into the next;
; 250 ms between writes clears Clipnik's 200 ms machine-write filter so both reach the repeat check, and
; 1800 ms afterwards lets the 1.5 s repeat window close before the next scenario
added := 0
scenario(name, expected, writes*) {
	global added
	s := strength()
	for i, w in writes {
		if (i > 1)
			Sleep 250
		w()
	}
	Sleep 1800
	got := strength() - s
	added += got
	check(name " (" got " recorded, " expected " expected)", got = expected)
}

pToken := Gdip_Startup()
scenario("snipping tool double write (OLE) recorded once", 1, putImageOle.Bind(0xFF22AA44), putImageOle.Bind(0xFF22AA44))
scenario("plain double write recorded once", 1, putImage.Bind(0xFF3366CC), putImage.Bind(0xFF3366CC))
scenario("same image after a pause is recorded again", 1, putImage.Bind(0xFF3366CC))
scenario("two different images in quick succession are both recorded", 2, putImageOle.Bind(0xFFCC4422), putImageOle.Bind(0xFF44CC22))
Gdip_Shutdown(pToken)

; remove the clips this test added, newest first, and only while the newest clip is provably one of ours:
; a 140x70 32-bit DIB is 39,200 bytes, and its dump is that plus a few format headers
clipsDir := A_ScriptDir "\..\cache\clips\"
removed := 0
loop added {
	n := strength()
	sz := FileExist(clipsDir n ".avc") ? FileGetSize(clipsDir n ".avc") : 0
	if (sz < 39200 || sz > 39400)
		break
	cj.runFunction("API.deleteClip(0,1)")
	Sleep 300
	removed++
}
check("removed its own " added " clips and nothing else (" removed " removed)", removed = added)

; history: only this test's rows (after the snapshot id, and the test's exact 140x70 size) and only JPEGs that
; did not exist before it started
cj.runFunction("execSql(delete from history where type=1 and id>" histBefore " and width=140 and height=70)")
loop files histDir "*.jpg"
	if !jpgsBefore.Has(A_LoopFileName) && (FileGetSize(A_LoopFileFullPath) < 2000)
		try FileDelete(A_LoopFileFullPath)

FileAppend((fails ? "FAILED " fails : "ALL PASSED") "`n", "*")
ExitApp fails
