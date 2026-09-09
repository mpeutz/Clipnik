; Opens each Clipjump window and saves a screenshot to tests\out\<name>.png. Requires a running Clipjump.
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
#Include ..\lib\vendor\Gdip_All.ahk
SetTitleMatchMode 2
cj := Clipjump()
pToken := Gdip_Startup()
DirCreate(A_ScriptDir "\out")
wins := [["main", "Clipjump [ Channel"], ["settings", "Clipjump Settings"], ["history", cj["TXT.HST__name"]], ["channelOrganizer", cj["TXT.ORG__name"]], ["pluginManagerGui", cj["TXT.PLG__name"]]]
for w in wins {
    cj.runLabel(w[1])
    if !WinWait(w[2] " ahk_class AutoHotkeyGUI", , 5)
        continue
    WinActivate(w[2] " ahk_class AutoHotkeyGUI")
    Sleep 700
    WinGetPos(&x, &y, &wd, &ht, w[2] " ahk_class AutoHotkeyGUI")
    pBitmap := Gdip_BitmapFromScreen(x "|" y "|" wd "|" ht)
    Gdip_SaveBitmapToFile(pBitmap, A_ScriptDir "\out\" w[1] ".png")
    Gdip_DisposeImage(pBitmap)
    WinClose(w[2] " ahk_class AutoHotkeyGUI")
    WinWaitClose(w[2] " ahk_class AutoHotkeyGUI", , 3)
    Sleep 300
}
Gdip_Shutdown(pToken)
FileAppend("done`n", "*")
