; Opens each Clipjump window through the API, verifies it appears, then closes it. Requires a running Clipjump.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\windows.ahk
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
SetTitleMatchMode 2
DetectHiddenWindows false
fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
errorDialog() {
    DetectHiddenWindows false
    return WinExist("Clipjump.ahk ahk_class #32770")
}
cj := Clipjump()
wins := [["main", "Clipjump [ Channel"], ["settings", "Clipjump Settings"], ["history", cj["TXT.HST__name"]], ["channelOrganizer", cj["TXT.ORG__name"]], ["pluginManagerGui", cj["TXT.PLG__name"]]]
for w in wins {
    cj.runLabel(w[1])
    found := WinWait(w[2] " ahk_class AutoHotkeyGUI", , 5)
    check(found, w[1] " opens window '" w[2] "'")
    check(!errorDialog(), w[1] " no error dialog")
    if found {
        WinActivate(w[2] " ahk_class AutoHotkeyGUI")
        Sleep 300
        WinClose(w[2] " ahk_class AutoHotkeyGUI")
        closed := WinWaitClose(w[2] " ahk_class AutoHotkeyGUI", , 3)
        check(closed, w[1] " closes")
        check(!errorDialog(), w[1] " no error dialog on close")
    }
    Sleep 300
}
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
