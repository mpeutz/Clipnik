; Opens the Settings window of the running Clipnik, walks every page and saves tests\out\settings-<page>.png.
; Optional argument: a page id to stop on (leaves the window open for manual inspection).
#Requires AutoHotkey v2.0
#Include lib\sandbox_guard.ahk   ; drives a running Clipnik: only ever a sandbox copy's
#Include ..\publicAPI.ahk
#Include ..\lib\gdiplus.ahk
#Include lib\gdiplus_test.ahk
SetTitleMatchMode 1
SetControlDelay -1
cj := Clipnik()
pToken := Gdip_Startup()
DirCreate(A_ScriptDir "\out")
title := "Clipnik Settings ahk_class AutoHotkeyGUI"
cj.runLabel("settings")
if !WinWait(title, , 5) {
	FileAppend("no settings window`n", "*")
	ExitApp 1
}
WinActivate(title)
Sleep 600
pages := Map("general", "General", "history", "Clipboard History", "shortcuts", "Shortcuts", "channels", "Channels", "appearance", "Appearance", "advanced", "Advanced")
for id in ["general", "history", "shortcuts", "channels", "appearance", "advanced"] {
	if (id != "general")
		ControlClick(pages[id], title)
	Sleep 350
	WinGetPos(&x, &y, &w, &h, title)
	pBitmap := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
	Gdip_SaveBitmapToFile(pBitmap, A_ScriptDir "\out\settings-" id ".png")
	Gdip_DisposeImage(pBitmap)
	if (A_Args.Length && A_Args[1] = id) {
		Gdip_Shutdown(pToken)
		ExitApp
	}
}
WinClose(title)
Gdip_Shutdown(pToken)
FileAppend("done`n", "*")
