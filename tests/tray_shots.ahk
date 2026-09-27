; Opens the tray menu card of the running Clipnik (via the API), captures it, opens the Channels submenu with
; the keyboard, captures again, then closes it with Esc. Saves tests\out\tray-*.png.
#Requires AutoHotkey v2.0
#Include lib\sandbox_guard.ahk   ; drives a running Clipnik: only ever a sandbox copy's
#Include ..\publicAPI.ahk
#Include ..\lib\vendor\Gdip_All.ahk
SendLevel 1
SetTitleMatchMode 1
CoordMode("Mouse", "Screen")
cj := Clipnik()
fails := 0
check(name, cond) {
	global fails
	FileAppend((cond ? "PASS " : "FAIL ") name "`n", "*")
	if !cond
		fails++
}
snap(name) {
	l := 99999, t := 99999, r := 0, b := 0
	for h in WinGetList("Clipnik_TrayMenu ahk_class AutoHotkeyGUI") {
		WinGetPos(&x, &y, &w, &hh, h)
		l := Min(l, x), t := Min(t, y), r := Max(r, x + w), b := Max(b, y + hh)
	}
	if (r = 0)
		return
	p := Gdip_Startup(), bm := Gdip_BitmapFromScreen((l - 8) "|" (t - 8) "|" (r - l + 16) "|" (b - t + 16))
	Gdip_SaveBitmapToFile(bm, A_ScriptDir "\out\tray-" name ".png"), Gdip_DisposeImage(bm), Gdip_Shutdown(p)
}
MouseMove(A_ScreenWidth - 120, A_ScreenHeight - 60)
cj.runFunction("TrayMenu_Open()")
check("card opens", WinWait("Clipnik_TrayMenu ahk_class AutoHotkeyGUI", , 5) != 0)
Sleep 600
snap("main")
Send("{Down}")
Sleep 250
Send("{Down}")
Sleep 250
Send("{Right}")
Sleep 600
check("submenu opens", WinGetList("Clipnik_TrayMenu ahk_class AutoHotkeyGUI").Length = 2)
snap("channels")
Send("{Esc}")
Sleep 300
Send("{Esc}")
Sleep 500
check("Esc closes", !WinExist("Clipnik_TrayMenu ahk_class AutoHotkeyGUI"))
; the real path: the tray icon posts AHK_NOTIFYICON with WM_RBUTTONUP to the script window
DetectHiddenWindows true
SetTitleMatchMode 2
scriptWin := WinExist("\Clipnik.ahk - ahk_class AutoHotkey")
SetTitleMatchMode 1
PostMessage(0x404, 0, 0x205, , "ahk_id " scriptWin)
check("tray right-click opens the card", WinWait("Clipnik_TrayMenu ahk_class AutoHotkeyGUI", , 5) != 0)
Sleep 600
check("standard menu did not appear", !WinExist("ahk_class #32768"))
MouseMove(A_ScreenWidth // 2, 80)
Click()
Sleep 600
check("click outside closes", !WinExist("Clipnik_TrayMenu ahk_class AutoHotkeyGUI"))
FileAppend((fails ? "FAILED " fails : "ALL PASSED") "`n", "*")
ExitApp fails
