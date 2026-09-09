; Image clip capture and preview against a RUNNING Clipjump.
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
#Include ..\lib\vendor\Gdip_All.ahk
SetTitleMatchMode 2
SendLevel 1
fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
errorDialog() => WinExist("Clipjump.ahk ahk_class #32770")
cj := Clipjump()
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
check(WinExist("Display_Cj ahk_class AutoHotkeyGUI"), "image preview window shown in paste mode")
SendEvent("x")
Sleep 300
SendEvent("{Ctrl up}")
Sleep 1000
check(!WinExist("Display_Cj ahk_class AutoHotkeyGUI"), "preview window closed after cancel")
check(!errorDialog(), "no error dialogs")
Gdip_Shutdown(pToken)
g.Destroy()
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails

Gdip_getLengthsLocal(img, &width, &height) {
    pBM := Gdip_CreateBitmapFromFile(img)
    width := Gdip_GetImageWidth(pBM), height := Gdip_GetImageHeight(pBM)
    Gdip_DisposeImage(pBM)
}
