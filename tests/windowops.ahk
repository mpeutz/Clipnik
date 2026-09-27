; Key operations inside the tool windows, against a RUNNING Clipnik:
; Settings Apply/OK round trip (the History and Organizer flows live in history_flow.ahk and organizer_flow.ahk).
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\windowops.ahk
#Requires AutoHotkey v2.0
#Include lib\sandbox_guard.ahk   ; drives a running Clipnik: only ever a sandbox copy's
#Include ..\publicAPI.ahk
SetTitleMatchMode 2
SendLevel 1
fails := 0
step(s) => FileAppend("     .. " s "`n", "*")
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
errorDialog() => WinExist("Clipnik.ahk ahk_class #32770")
root := A_ScriptDir "\.."
cj := Clipnik()
strength() => Integer(cj.runFunction("API.getChStrength(0)"))
stamp := "wo-" A_TickCount

step("Settings: OK without changes leaves settings.ini identical")
before := FileRead(root "\settings.ini", "RAW")
cj.runLabel("settings")
if WinWait("Clipnik Settings ahk_class AutoHotkeyGUI", , 5) {
    WinActivate("Clipnik Settings ahk_class AutoHotkeyGUI")
    Sleep 500
    ControlClick("OK", "Clipnik Settings ahk_class AutoHotkeyGUI")
    WinWaitClose("Clipnik Settings ahk_class AutoHotkeyGUI", , 5)
    Sleep 500
    after := FileRead(root "\settings.ini", "RAW")
    same := before.Size = after.Size && DllCall("RtlCompareMemory", "Ptr", before, "Ptr", after, "Ptr", before.Size, "Ptr") = before.Size
    check(same, "settings.ini byte-identical after OK (" before.Size " vs " after.Size " bytes)")
} else
    check(false, "settings window did not open")
check(!errorDialog(), "no error after Settings")

step("Settings: toggle 'Beep when copied', Apply, verify ini, toggle back")
cj.runLabel("settings")
WinWait("Clipnik Settings ahk_class AutoHotkeyGUI", , 5)
WinActivate("Clipnik Settings ahk_class AutoHotkeyGUI")
Sleep 500
orig := IniRead(root "\settings.ini", "Main", "CopyBeep", "")
ControlClick(cj["TXT.SET_copybeep"], "Clipnik Settings ahk_class AutoHotkeyGUI")
Sleep 300
ControlClick("OK", "Clipnik Settings ahk_class AutoHotkeyGUI")
WinWaitClose("Clipnik Settings ahk_class AutoHotkeyGUI", , 5)
Sleep 800
now := IniRead(root "\settings.ini", "Main", "CopyBeep", "")
check(now != orig, "CopyBeep changed in ini (" orig " -> " now ")")
check(cj["ini_CopyBeep"] = now, "ini_CopyBeep reloaded in memory")
cj.runLabel("settings")
WinWait("Clipnik Settings ahk_class AutoHotkeyGUI", , 5)
WinActivate("Clipnik Settings ahk_class AutoHotkeyGUI")
Sleep 500
ControlClick(cj["TXT.SET_copybeep"], "Clipnik Settings ahk_class AutoHotkeyGUI")
Sleep 300
ControlClick("OK", "Clipnik Settings ahk_class AutoHotkeyGUI")
WinWaitClose("Clipnik Settings ahk_class AutoHotkeyGUI", , 5)
Sleep 800
check(IniRead(root "\settings.ini", "Main", "CopyBeep", "") = orig, "CopyBeep restored")
check(!errorDialog(), "no error after Settings round trip")

; History and Organizer are WebView2 pages now: see history_flow.ahk and organizer_flow.ahk

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
