; Image clip capture and preview against a RUNNING Clipnik.
#Requires AutoHotkey v2.0
#Include lib\sandbox_guard.ahk   ; drives a running Clipnik: only ever a sandbox copy's
#Include ..\publicAPI.ahk
#Include ..\lib\gdiplus.ahk
SetTitleMatchMode 2
SendLevel 1
fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
errorDialog() => WinExist("Clipnik.ahk ahk_class #32770")
cj := Clipnik()
; the history-row check below needs image storage on for the run, the same as tests/history_image.ahk
oldImageStored := cj["ini_IsImageStored"]
cj.setVar("ini_IsImageStored", 1)
; keep the channel well below its clip limit so compaction cannot renumber clips mid-test
if (Integer(cj.runFunction("API.getChStrength(0)")) >= Integer(cj["TOTALCLIPS"]) - 6)
    cj.runFunction("compacter()")
strength() => Integer(cj.runFunction("API.getChStrength(0)"))
root := A_ScriptDir "\.."
before := strength()
; put a 120x80 red bitmap on the clipboard
pToken := Gdip_Startup()
pBitmap := Gdip_CreateBitmap(120, 80)
G := Gdip_GraphicsFromImage(pBitmap)
pBrush := Gdip_BrushCreateSolid(0xFFCC2222)
Gdip_FillRectangle(G, pBrush, 0, 0, 120, 80)
Gdip_DeleteBrush(pBrush), Gdip_DeleteGraphics(G)
Gdip_SetBitmapToClipboard(pBitmap)
Gdip_DisposeImage(pBitmap)
Sleep 1500
after := strength()
check(after = before + 1, "image capture created a clip (" before " -> " after ")")
check(cj.getClipAt(0, 1) = "", "clip 1 text is empty for an image")
thumb := root "\cache\thumbs\" after ".jpg"
check(FileExist(thumb), "thumbnail written: " thumb)
Gdip_getLengthsLocal(thumb, &w, &h)
check(w = 120 && h = 80, "thumbnail is 120x80 (" w "x" h ")")

g := Gui("+AlwaysOnTop", "cj-img-target")
ed := g.Add("Edit", "w400 h100 +Multi")
g.Show()
WinWaitActive("cj-img-target", , 5)
ed.Focus()
Sleep 400
SendEvent("{Ctrl down}v")
Sleep 900
check(WinExist("Clipnik_HUD ahk_class AutoHotkeyGUI"), "HUD card shown for the image clip")
SendEvent("x")
Sleep 300
SendEvent("{Ctrl up}")
Sleep 1000
check(!WinExist("Clipnik_HUD ahk_class AutoHotkeyGUI"), "HUD card hidden after cancel")
check(!errorDialog(), "no error dialogs")

n := Integer(cj["CURSAVE"]), ch := Integer(cj["CN.NG"])
check(cj.runFunction("ClipType_KindOf(" ch "," n ")") = "image", "image clip kind is image")
dim := cj.runFunction("Image_DimOf(" ch "," n ")")
check(RegExMatch(dim, "^\d+x\d+$"), "image clip records its size: [" dim "]")
row := cj.runFunction("Image_LastHistoryDims()")
check(RegExMatch(row, "^image \d+ \d+$"), "history row carries the kind and size: [" row "]")

Gdip_Shutdown(pToken)
g.Destroy()
cj.setVar("ini_IsImageStored", oldImageStored)
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails

Gdip_getLengthsLocal(img, &width, &height) {
    pBM := Gdip_CreateBitmapFromFile(img)
    width := Gdip_GetImageWidth(pBM), height := Gdip_GetImageHeight(pBM)
    Gdip_DisposeImage(pBM)
}
