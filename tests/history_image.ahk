; Turns image storage on for the run, copies a generated image, checks it lands in the history table and that the
; History page previews it (image URL served from cache.clipjump). Restores the setting.
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
#Include ..\lib\vendor\Gdip_All.ahk
SendLevel 1
SetTitleMatchMode 1
cj := Clipjump()
title := "Clipjump Clipboard History ahk_class AutoHotkeyGUI"
logFile := A_Temp "\Clipjump\webhost.log"
fails := 0
check(name, cond) {
	global fails
	FileAppend((cond ? "PASS " : "FAIL ") name "`n", "*")
	if !cond
		fails++
}
old := cj["ini_IsImageStored"]
cj.setVar("ini_IsImageStored", 1)
imageFiles() {
	n := 0
	loop files A_ScriptDir "\..\cache\history\*.jpg"
		n++
	return n
}
before := imageFiles()
pToken := Gdip_Startup()
pBitmap := Gdip_CreateBitmap(160, 90)
G := Gdip_GraphicsFromImage(pBitmap)
pBrush := Gdip_BrushCreateSolid(0xFF2266CC)
Gdip_FillRectangle(G, pBrush, 0, 0, 160, 90)
Gdip_DeleteBrush(pBrush), Gdip_DeleteGraphics(G)
Gdip_SetBitmapToClipboard(pBitmap)
Gdip_DisposeImage(pBitmap)
Sleep 1800
after := imageFiles()
check("image stored in history (" before " -> " after ")", after = before + 1)
try FileDelete(logFile)
cj.runLabel("history")
check("window opens", WinWait(title, , 8) != 0)
WinActivate(title)
Sleep 2000
Send("{Down}")
Sleep 900
txt := FileExist(logFile) ? FileRead(logFile) : ""
check("preview carries the image url", InStr(txt, '"url":"https://cache.clipjump/history/'))
Sleep 600
WinGetPos(&x, &y, &w, &h, title)
b := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
Gdip_SaveBitmapToFile(b, A_ScriptDir "\out\history-image.png"), Gdip_DisposeImage(b)
Gdip_Shutdown(pToken)
Send("{Esc}")
Sleep 500
cj.setVar("ini_IsImageStored", old)
; remove the test image again so it does not linger in the user's history
cj.runFunction("execSql(delete from history where type=1 and size=870)")
loop files A_ScriptDir "\..\cache\history\*.jpg"
	if (FileGetSize(A_LoopFileFullPath) = 870)
		try FileDelete(A_LoopFileFullPath)
FileAppend((fails ? "FAILED " fails : "ALL PASSED") "`n", "*")
ExitApp fails
