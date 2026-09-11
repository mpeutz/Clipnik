; Screenshots the live HUD card and toast while driving a RUNNING Clipjump: copy, Ctrl+V, V, X, F search.
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
#Include ..\lib\vendor\Gdip_All.ahk
SetTitleMatchMode 2
SendLevel 1
cj := Clipjump()
; keep the channel well below its clip limit so compaction cannot renumber clips mid-test
if (Integer(cj.runFunction("API.getChStrength(0)")) >= Integer(cj["TOTALCLIPS"]) - 6)
    cj.runFunction("compacter()")
errorDialog() => WinExist("Clipjump.ahk ahk_class #32770")
fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
snapWin(title, name) {
    if !WinExist(title)
        return check(false, name ": window '" title "' not found")
    WinGetPos(&x, &y, &w, &h, title)
    pToken := Gdip_Startup()
    pBitmap := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
    Gdip_SaveBitmapToFile(pBitmap, A_ScriptDir "\out\live-" name ".png")
    Gdip_DisposeImage(pBitmap), Gdip_Shutdown(pToken)
    check(true, name " captured " w "x" h)
}
stamp := "live-" A_TickCount
A_Clipboard := stamp " first clip with a fairly long sentence so the preview wraps onto a second line of the card"
Sleep 500
snapWin("Clipjump_Toast ahk_class AutoHotkeyGUI", "toast")
Sleep 600
A_Clipboard := stamp " second"
Sleep 800
g := Gui("+AlwaysOnTop", "cj-live-target")
ed := g.Add("Edit", "w500 h200 +Multi")
g.Show()
WinWaitActive("cj-live-target", , 5)
ed.Focus()
Sleep 400
SendEvent("{Ctrl down}v")
Sleep 600
check(WinExist("Clipjump_HUD ahk_class AutoHotkeyGUI"), "HUD card visible in paste mode")
check(WinActive("cj-live-target"), "target window still active (card did not steal focus)")
snapWin("Clipjump_HUD ahk_class AutoHotkeyGUI", "card-normal")
SendEvent("v")
Sleep 500
snapWin("Clipjump_HUD ahk_class AutoHotkeyGUI", "card-clip2")
SendEvent("x")
Sleep 500
snapWin("Clipjump_HUD ahk_class AutoHotkeyGUI", "card-cancelmode")
seen := ""
loop 6 {
    SendEvent("x")
    Sleep 300
    seen .= cj["ctrlRef"] " "
}
check(InStr(seen, "delete cut copy deleteAll cancel"), "X cycles through the modes: " seen)
while (cj["ctrlRef"] != "cancel") {
    SendEvent("x")
    Sleep 300
}
SendEvent("{Ctrl up}")
Sleep 900
check(!WinExist("Clipjump_HUD ahk_class AutoHotkeyGUI"), "card hidden after release")
check(ed.Value = "", "cancelled: nothing pasted")

; search
ed.Value := ""
SendEvent("{Ctrl down}v")
Sleep 500
SendEvent("f")
Sleep 500
SendEvent("{Ctrl up}")
Sleep 300
check(cj["SPM.ACTIVE"] = 1, "search active after F")
SendEvent("first")
Sleep 900
snapWin("Clipjump_HUD ahk_class AutoHotkeyGUI", "card-search")
check(InStr(cj["temp_clipboard"], stamp " first"), "typed search jumped to 'first' clip")
check(WinActive("cj-live-target"), "target window still active while searching")
SendEvent("{Enter}")
Sleep 1500
check(InStr(ed.Value, stamp " first"), "Enter pasted the found clip: [" SubStr(ed.Value, 1, 40) "]")
check(cj["ctrlRef"] = "" && cj["SPM.ACTIVE"] = "", "paste mode and search ended")

; F1 help
ed.Value := ""
SendEvent("{Ctrl down}v")
Sleep 500
SendEvent("{F1}")
Sleep 500
snapWin("Clipjump_HUD ahk_class AutoHotkeyGUI", "card-help")
SendEvent("x")
Sleep 300
SendEvent("{Ctrl up}")
Sleep 800

; action mode
SendEvent("^+a")
Sleep 800
check(cj.runFunction("Ring_IsOpen()") = 1, "action ring shown")
snapWin("Clipjump_Ring ahk_class AutoHotkeyGUI", "card-actionmode")
SendEvent("{Esc}")
Sleep 500
check(cj.runFunction("Ring_IsOpen()") = 0, "action ring closed by Esc")
check(!errorDialog(), "no error dialogs")
g.Destroy()
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
