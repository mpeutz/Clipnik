; Ignored Windows: adds this script's own window class through the picker, checks settings.ini and that paste
; mode passes Ctrl+V straight through (no card) without a restart, then removes the class again.
; Needs an idle desktop. The class is restored in the ini even when a check fails.
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
SendLevel 1
SetTitleMatchMode 1
SetControlDelay -1
cj := Clipjump()
ini := A_ScriptDir "\..\settings.ini"
title := "Clipjump " cj["TXT.IGN__name"] " ahk_class AutoHotkeyGUI"
fails := 0
check(name, cond) {
	global fails
	FileAppend((cond ? "PASS " : "FAIL ") name "`n", "*")
	if !cond
		fails++
}
oldList := IniRead(ini, "Advanced", "ignoreWindows", "")

; the target window: a plain Edit in this script (class AutoHotkeyGUI)
tg := Gui("+AlwaysOnTop", "ignored_flow target")
edt := tg.Add("Edit", "w300 r5")
tg.Show("x100 y100")
Sleep 400
tgClass := WinGetClass(tg.Hwnd)

cj.runLabel("classTool")
check("window opens", WinWait(title, , 5) != 0)
WinActivate(title)
Sleep 400
ControlClick("&Add Window's Class", title)
Sleep 400
WinActivate(tg.Hwnd)
Sleep 600
Send("{Space}")
Sleep 800
check("class written to ini", InStr(IniRead(ini, "Advanced", "ignoreWindows", ""), tgClass "|"))
check("class listed", InStr(ListViewGetContent("", "SysListView321", title), tgClass))

; paste mode must pass Ctrl+V straight through now (no card)
marker := "ignored-flow-" A_TickCount
A_Clipboard := marker
Sleep 300
WinActivate(tg.Hwnd)
edt.Focus()
Sleep 300
SendEvent("{Ctrl down}v")
Sleep 500
SendEvent("{Ctrl up}")
Sleep 800
hudShown := WinExist("Clipjump_HUD ahk_class AutoHotkeyGUI") && (WinGetStyle("Clipjump_HUD ahk_class AutoHotkeyGUI") & 0x10000000)
check("no paste-mode card in ignored window", !hudShown)
check("text pasted through", InStr(edt.Value, marker))

; delete it again
WinActivate(title)
Sleep 300
ControlClick("SysListView321", title, , "Left", 1, "x20 y8")
Sleep 200
ControlClick("&Delete Class", title)
Sleep 500
check("class removed from ini", IniRead(ini, "Advanced", "ignoreWindows", "") = oldList)
ControlClick("Close", title)
Sleep 300
check("window closed", !WinExist(title))
IniWrite(oldList, ini, "Advanced", "ignoreWindows")
tg.Destroy()
FileAppend((fails ? "FAILED " fails : "ALL PASSED") "`n", "*")
ExitApp fails
