; Renders the Common Formats "Choose Format" dialog in dark and light and saves screenshots to
; tests\out\commonformats-<mode>.png. Standalone: stubs the few Clipjump globals the plugin touches.
; Never sends keys or moves the mouse; the dialog is closed with WinClose (which cancels it).
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\lib\v2compat.ahk
#Include ..\lib\vendor\Gdip_All.ahk
#Include ..\lib\translations.ahk
#Include ..\src\ui\native\Theme.ahk
#Include ..\plugins\pformat.commonformats.ahk
SetWorkingDir A_ScriptDir "\.."
FileEncoding "UTF-8"

OnError(commonformats_demo_OnError)
commonformats_demo_OnError(e, mode) {
	FileAppend("ERROR " e.Message " (" e.File ":" e.Line ") " e.Extra "`n", "*")
	return true
}

global STORE := CJMap(), CJGUI := Map()
global TXT := Translations_load("languages/english.txt")
global PROGNAME := "Clipjump"

DirExist("tests\out") || DirCreate("tests\out")

; The plugin resolves its own source (for the format list) and its user.ahk lib relative to
; A_ScriptDir, which here is tests\ rather than the repo root. Mirror just enough of the real
; plugins tree so the ListBox populates as it does inside the real app, then remove it afterwards.
demoPluginsDir := A_ScriptDir "\plugins"
DirCreate(demoPluginsDir "\pformat.commonformats.lib")
FileCopy(A_ScriptDir "\..\plugins\pformat.commonformats.ahk", demoPluginsDir "\pformat.commonformats.ahk", true)
FileCopy(A_ScriptDir "\..\plugins\pformat.commonformats.lib\user.ahk", demoPluginsDir "\pformat.commonformats.lib\user.ahk", true)

snap(mode) {
	if !WinWait("Choose Format ahk_class AutoHotkeyGUI", , 5)
		return
	hwnd := WinExist("Choose Format ahk_class AutoHotkeyGUI")
	WinGetPos(&x, &y, &w, &h, hwnd)
	pToken := Gdip_Startup()
	pBitmap := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
	Gdip_SaveBitmapToFile(pBitmap, A_ScriptDir "\out\commonformats-" mode ".png")
	Gdip_DisposeImage(pBitmap), Gdip_Shutdown(pToken)
	WinClose(hwnd)
}

for mode in ["dark", "light"] {
	Theme.Init(mode, "76B84E")
	SetTimer(snap.Bind(mode), -300)
	plugin_pformat_commonformats("https://example.com/Some Page?utm_source=x")
}

try DirDelete(demoPluginsDir, true)

FileAppend("done`n", "*")
ExitApp
