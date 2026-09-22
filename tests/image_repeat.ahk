; A snipping tool writes the same image to the clipboard twice within a moment: Clipnik must record it once,
; while two deliberate copies (Ctrl+C in between) are both kept. Needs a running Clipnik and an idle desktop.
#Requires AutoHotkey v2.0
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
; the highest history id before this test copies anything, so its cleanup can name the rows it created
; instead of deleting every small image in the user's history
histBefore := Integer(cj.runFunction("History_NewestId()"))
putImage(color) {
	pBitmap := Gdip_CreateBitmap(140, 70)
	G := Gdip_GraphicsFromImage(pBitmap)
	pBrush := Gdip_BrushCreateSolid(color)
	Gdip_FillRectangle(G, pBrush, 0, 0, 140, 70)
	Gdip_DeleteBrush(pBrush), Gdip_DeleteGraphics(G)
	Gdip_SetBitmapToClipboard(pBitmap)
	Gdip_DisposeImage(pBitmap)
}
pToken := Gdip_Startup()
before := strength()
putImage(0xFF22AA44)
Sleep 250
putImage(0xFF22AA44)          ; the second write a snipping tool makes
Sleep 1800
check("double clipboard write recorded once (" before " -> " strength() ")", strength() = before + 1)
Sleep 1600
putImage(0xFF22AA44)          ; later, the same image again: a new capture
Sleep 1800
check("same image after a pause is recorded again", strength() = before + 2)
Gdip_Shutdown(pToken)
; clean up the two test clips
cj.runFunction("API.deleteClip(0,1)")
Sleep 300
cj.runFunction("API.deleteClip(0,1)")
Sleep 300
cj.runFunction("execSql(delete from history where type=1 and id>" histBefore ")")
loop files A_ScriptDir "\..\cache\history\*.jpg"
	if (FileGetSize(A_LoopFileFullPath) < 2000)
		try FileDelete(A_LoopFileFullPath)
check("clips cleaned up", strength() = before)
FileAppend((fails ? "FAILED " fails : "ALL PASSED") "`n", "*")
ExitApp fails
