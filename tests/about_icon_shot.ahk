; Opens About, saves the icon area from the screen to tests\out\about_icon.png, and closes it. Requires a running Clipjump.
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
#Include ..\lib\vendor\Gdip_All.ahk
SetTitleMatchMode 2
cj := Clipjump()
pToken := Gdip_Startup()
DirCreate(A_ScriptDir "\out")
t := "About Clipjump ahk_class AutoHotkeyGUI"
cj.runLabel("main")
if WinWait(t, , 5) {
    WinActivate(t)
    Sleep 700
    WinGetClientPos(&x, &y, &w, , t)
    pBitmap := Gdip_BitmapFromScreen(Round(x + w / 2 - 40) "|" (y + 12) "|80|80")
    Gdip_SaveBitmapToFile(pBitmap, A_ScriptDir "\out\about_icon.png")
    Gdip_DisposeImage(pBitmap)
    WinClose(t)
}
Gdip_Shutdown(pToken)
FileAppend("done`n", "*")
