; Key operations inside the tool windows, against a RUNNING Clipjump:
; Settings Apply/OK round trip, History preview + Ctrl+C copy, Organizer new clip + preview + delete.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\windowops.ahk
#Requires AutoHotkey v2.0
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
errorDialog() => WinExist("Clipjump.ahk ahk_class #32770")
root := A_ScriptDir "\.."
cj := Clipjump()
strength() => Integer(cj.runFunction("API.getChStrength(0)"))
stamp := "wo-" A_TickCount

step("Settings: OK without changes leaves settings.ini identical")
before := FileRead(root "\settings.ini", "RAW")
cj.runLabel("settings")
if WinWait("Clipjump Settings ahk_class AutoHotkeyGUI", , 5) {
    WinActivate("Clipjump Settings ahk_class AutoHotkeyGUI")
    Sleep 500
    ControlClick("OK", "Clipjump Settings ahk_class AutoHotkeyGUI")
    WinWaitClose("Clipjump Settings ahk_class AutoHotkeyGUI", , 5)
    Sleep 500
    after := FileRead(root "\settings.ini", "RAW")
    same := before.Size = after.Size && DllCall("RtlCompareMemory", "Ptr", before, "Ptr", after, "Ptr", before.Size, "Ptr") = before.Size
    check(same, "settings.ini byte-identical after OK (" before.Size " vs " after.Size " bytes)")
} else
    check(false, "settings window did not open")
check(!errorDialog(), "no error after Settings")

step("Settings: toggle 'Beep when copied', Apply, verify ini, toggle back")
cj.runLabel("settings")
WinWait("Clipjump Settings ahk_class AutoHotkeyGUI", , 5)
WinActivate("Clipjump Settings ahk_class AutoHotkeyGUI")
Sleep 500
orig := IniRead(root "\settings.ini", "Main", "CopyBeep", "")
ControlClick(cj["TXT.SET_copybeep"], "Clipjump Settings ahk_class AutoHotkeyGUI")
Sleep 300
ControlClick("OK", "Clipjump Settings ahk_class AutoHotkeyGUI")
WinWaitClose("Clipjump Settings ahk_class AutoHotkeyGUI", , 5)
Sleep 800
now := IniRead(root "\settings.ini", "Main", "CopyBeep", "")
check(now != orig, "CopyBeep changed in ini (" orig " -> " now ")")
check(cj["ini_CopyBeep"] = now, "ini_CopyBeep reloaded in memory")
cj.runLabel("settings")
WinWait("Clipjump Settings ahk_class AutoHotkeyGUI", , 5)
WinActivate("Clipjump Settings ahk_class AutoHotkeyGUI")
Sleep 500
ControlClick(cj["TXT.SET_copybeep"], "Clipjump Settings ahk_class AutoHotkeyGUI")
Sleep 300
ControlClick("OK", "Clipjump Settings ahk_class AutoHotkeyGUI")
WinWaitClose("Clipjump Settings ahk_class AutoHotkeyGUI", , 5)
Sleep 800
check(IniRead(root "\settings.ini", "Main", "CopyBeep", "") = orig, "CopyBeep restored")
check(!errorDialog(), "no error after Settings round trip")

step("History: preview of the newest text entry opens and closes; Ctrl+C copies it")
A_Clipboard := stamp " history"
Sleep 700
cj.runLabel("history")
hist := cj["TXT.HST__name"] " ahk_class AutoHotkeyGUI"
WinWait(hist, , 5)
WinActivate(hist)
Sleep 600
ControlFocus("SysListView321", hist)
Sleep 200
SendEvent("{Home}")
Sleep 300
ControlClick(cj["TXT.HST_preview"], hist)
prev := cj["TXT.PRV__name"] " ahk_class AutoHotkeyGUI"
check(WinWait(prev, , 5), "preview window opened")
Sleep 800
WinClose(prev)
check(WinWaitClose(prev, , 5), "preview window closed")
WinActivate(hist)
Sleep 300
ControlFocus("SysListView321", hist)
Sleep 200
A_Clipboard := ""
SendEvent("^c")
Sleep 1200
check(InStr(A_Clipboard, stamp " history"), "Ctrl+C in history copied the entry: [" A_Clipboard "]")
WinClose(hist)
WinWaitClose(hist, , 5)
check(!errorDialog(), "no error after History")

step("Organizer: Ctrl+N new clip, Enter preview, Del delete")
before := strength()
cj.runLabel("channelOrganizer")
org := cj["TXT.ORG__name"] " ahk_class AutoHotkeyGUI"
WinWait(org, , 5)
WinActivate(org)
Sleep 600
SendEvent("^n")
if WinWait(cj["TXT.ORG_createnew"] " ahk_class AutoHotkeyGUI", , 5) {
    Sleep 400
    SendEvent(stamp " organizer")
    Sleep 200
    ControlClick("OK", cj["TXT.ORG_createnew"] " ahk_class AutoHotkeyGUI")
    Sleep 1500
    check(strength() = before + 1, "new clip added (" before " -> " strength() ")")
    check(cj.getClipAt(0, 1) = stamp " organizer", "new clip is clip 1: " cj.getClipAt(0, 1))
} else
    check(false, "new clip dialog did not open")
WinActivate(org)
Sleep 300
ControlFocus("SysListView321", org)
Sleep 200
SendEvent("{Home}")
Sleep 300
SendEvent("{Enter}")
check(WinWait(prev, , 5), "organizer preview opened")
Sleep 600
WinClose(prev)
WinWaitClose(prev, , 5)
WinActivate(org)
Sleep 300
ControlFocus("SysListView321", org)
Sleep 200
SendEvent("{Home}")
Sleep 300
n := strength()
SendEvent("{Del}")
Sleep 1500
check(strength() = n - 1, "Del removed the clip (" n " -> " strength() ")")
WinClose(org)
WinWaitClose(org, , 5)
check(!errorDialog(), "no error after Organizer")

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
