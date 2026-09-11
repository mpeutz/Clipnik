; Drives the Settings window of the running Clipjump: records a hotkey, changes a spinner and the theme,
; applies, and checks settings.ini and the live hotkey. Restores the previous values at the end.
; Needs an idle desktop. Logs to tests\out\settings_flow.log; prints PASS/FAIL lines.
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
#Include ..\lib\vendor\Gdip_All.ahk
SendLevel 1
SetTitleMatchMode 1
SetControlDelay -1
SetKeyDelay 30, 30
cj := Clipjump()
ini := A_ScriptDir "\..\settings.ini"
title := "Clipjump Settings ahk_class AutoHotkeyGUI"
logFile := A_ScriptDir "\out\settings_flow.log"
try FileDelete(logFile)
fails := 0
check(name, cond) {
	global fails
	FileAppend((cond ? "PASS " : "FAIL ") name "`n", "*")
	FileAppend((cond ? "PASS " : "FAIL ") name "`n", logFile)
	if !cond
		fails++
}
snap(name) {
	global title
	WinGetPos(&x, &y, &w, &h, title)
	p := Gdip_Startup(), b := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
	Gdip_SaveBitmapToFile(b, A_ScriptDir "\out\settings-" name ".png"), Gdip_DisposeImage(b), Gdip_Shutdown(p)
}

oldTheme := IniRead(ini, "Main", "Theme", "system")
oldThreshold := IniRead(ini, "Main", "Threshold", 10)
oldHold := IniRead(ini, "Shortcuts", "holdClip_K", "")

cj.runLabel("settings")
check("settings window opens", WinWait(title, , 5) != 0)
WinActivate(title)
Sleep 500

; --- Apply is disabled until something changes
check("apply disabled when clean", !ControlGetEnabled("&Apply", title))

; --- spinner: Threshold on the General page (second Edit on the page)
ControlClick("Edit2", title)
Sleep 150
Send("^a" (oldThreshold + 1))
Sleep 200
ControlClick("&Apply", title)
Sleep 800
check("threshold written", IniRead(ini, "Main", "Threshold", "") = oldThreshold + 1)

; --- hotkey recorder: Hold Clip on the Shortcuts page
ControlClick("Shortcuts", title)
Sleep 300
; the Hold Clip field is the recorder directly under the CAPTURE header: locate through the label's position
ControlGetPos(&lx, &ly, , , "Hold Clip", title)
found := ""
loop 20 {
	try {
		ControlGetPos(&ex, &ey, , , "Edit" A_Index, title)
		if (Abs(ey - ly) < 8 && ex > lx)
			found := "Edit" A_Index
	}
}
check("hold clip recorder found", found != "")
ControlClick(found, title)
Sleep 300
check("recorder shows prompt", InStr(ControlGetText(found, title), "Press"))
Send("^!{F9}")
Sleep 500
check("recorder shows Ctrl + Alt + F9", ControlGetText(found, title) = "Ctrl + Alt + F9")
ControlClick("&Apply", title)
Sleep 800
check("hotkey written", IniRead(ini, "Shortcuts", "holdClip_K", "") = "^!F9")

; --- theme switch: Appearance page, Theme DDL -> Light, Apply, screenshot, then back
ControlClick("Appearance", title)
Sleep 300
ControlChooseIndex(3, "ComboBox2", title)
Sleep 200
ControlClick("&Apply", title)
Sleep 1500
check("theme written", IniRead(ini, "Main", "Theme", "") = "light")
check("window rebuilt after theme change", WinExist(title) != 0)
WinActivate(title)
Sleep 400
snap("light-appearance")
ControlClick("General", title)
Sleep 300
snap("light-general")
ControlClick("Appearance", title)
Sleep 300
ControlChooseIndex(oldTheme = "dark" ? 2 : (oldTheme = "light" ? 3 : 1), "ComboBox2", title)
Sleep 200
ControlClick("&Apply", title)
Sleep 1500
check("theme restored", IniRead(ini, "Main", "Theme", "") = oldTheme)

; --- Rules page: Add opens the editor, Cancel closes it
WinActivate(title)
ControlClick(cj["TXT.SET_rules"], title)
Sleep 400
check("rules list shown", ControlGetVisible("SysListView321", title))
ControlClick(cj["TXT.SET_ruleAdd"], title)
check("rule editor opens", WinWait(cj["TXT.RUL_title"] " ahk_class AutoHotkeyGUI", , 4) != 0)
Sleep 300
ControlClick(cj["TXT.SET_cancel"], cj["TXT.RUL_title"] " ahk_class AutoHotkeyGUI")
check("rule editor closed", WinWaitClose(cj["TXT.RUL_title"] " ahk_class AutoHotkeyGUI", , 3))

; --- restore the other values through the window and close with OK
WinActivate(title)
ControlClick("General", title)
Sleep 300
ControlClick("Edit2", title)
Sleep 150
Send("^a" oldThreshold)
Sleep 200
ControlClick("Shortcuts", title)
Sleep 300
ControlClick(found, title)
Sleep 300
if (oldHold = "")
	Send("{Backspace}")
else
	Send(oldHold)
Sleep 300
ControlClick("OK", title)
Sleep 800
check("window closed on OK", !WinExist(title))
check("threshold restored", IniRead(ini, "Main", "Threshold", "") = oldThreshold)
check("hold clip restored", IniRead(ini, "Shortcuts", "holdClip_K", "") = oldHold)
FileAppend((fails ? "FAILED " fails : "ALL PASSED") "`n", "*")
ExitApp fails
