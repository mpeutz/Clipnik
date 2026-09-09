; Renders the HUD card and toasts in every mode, in dark and light, and saves screenshots to tests\out\hud-*.png.
; Standalone: stubs the few Clipjump globals the modules touch. Run with Clipjump NOT running (it uses hotkeys).
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\lib\v2compat.ahk
#Include ..\lib\vendor\Gdip_All.ahk
#Include ..\src\ui\native\Theme.ahk
#Include ..\src\ui\native\Toast.ahk
#Include ..\src\ui\native\Hud.ahk
#Include ..\lib\translations.ahk
SetWorkingDir A_ScriptDir "\.."
FileEncoding "UTF-8"
global STORE := CJMap(), CJGUI := Map(), ACTIONS := CJMap()
global ini_pstMode_X := "", ini_pstMode_Y := "", ini_LANG := "english"
global CN := CJMap("Name", "Default", "NG", 0), realclipno := 3, CURSAVE := 40, curPformat := "", fixStatus := "", halfClip := ""
global temp_clipboard := "", THUMBS_dir := "cache/thumbs", TEMPSAVE := 1, realActive := 1, SPM := CJMap(), ctrlRef := ""
global TXT := Translations_load("languages/english.txt")
global PROGNAME := "Clipjump"
hkZ(key, fn, status := 1) => Hotkey(key, fn, status ? "On" : "Off")
clipPref(ch, clip, name) => (name = "Tags") ? "work urgent" : ""
GetClipboardFormat(type := 1) => "[Text]"
fillWithSpaces(text := "", limit := 35) {
	r := ""
	loop limit - StrLen(text)
		r .= A_Space
	return text r
}
Gdip_getLengths(img, &w, &h) {
	t := Gdip_Startup(), p := Gdip_CreateBitmapFromFile(img), w := Gdip_GetImageWidth(p), h := Gdip_GetImageHeight(p), Gdip_DisposeImage(p), Gdip_Shutdown(t)
}
snap(name) {
	FileAppend(A_TickCount " snap " name "`n", A_ScriptDir "\out\hud_demo.log")
	Sleep 250
	Hud.GetPos(&x, &y, &w, &h)
	if (w = 0)
		return
	pToken := Gdip_Startup()
	pBitmap := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
	Gdip_SaveBitmapToFile(pBitmap, A_ScriptDir "\out\hud-" name ".png")
	Gdip_DisposeImage(pBitmap), Gdip_Shutdown(pToken)
}
long := "Brings the Latest Resources widget in line with the Figma mockup: the shared resource card is restyled, the section header is restructured with the carousel prev/next buttons moved into the header, and the grid now collapses to a single column below 720px. Also fixes a regression where the fallback image was never shown."
thumb := ""
loop files "cache\thumbs\*.jpg"
	thumb := A_LoopFileFullPath
for themeMode in ["dark", "light"] {
	Theme.Init(themeMode)
	Hud.Init()
	Hud.Restyle()
	MouseMove(300, 200)
	s := Hud.NewState()
	s.channel := "Default", s.index := 3, s.total := 40, s.format := "TEXT", s.tags := "work urgent", s.text := long
	Hud.Render(s), snap(themeMode "-normal")
	s.fixed := 1, s.pformat := "Trim Formatting", s.text := "short clip"
	Hud.Render(s), snap(themeMode "-badges")
	s.mode := "delete", Hud.Render(s), snap(themeMode "-modering")
	s.mode := "normal", s.searchActive := 1, s.searchTerm := "figma", s.matchIndex := 2, s.matchCount := 7, s.text := long
	Hud.Render(s), snap(themeMode "-search")
	s.searchActive := 0, s.mode := "help", Hud.Render(s), snap(themeMode "-help")
	if thumb {
		s.mode := "normal", s.format := "IMAGE", s.text := "", s.imagePath := thumb
		Hud.Render(s), snap(themeMode "-image")
		s.imagePath := "", s.format := "TEXT", s.text := "x"
	}
	Hud.Message("Cancelled"), snap(themeMode "-message")
	; menu (non-blocking snapshot: render the state Menu() would build)
	m := Hud.NewState(), m.mode := "menu"
	items := [{key: "H", caption: "Clipboard History"}, {key: "O", caption: "Channel Organizer"}, {key: "E", caption: "Settings"}, {key: "Esc", caption: "Exit"}]
	menuText := "Clipjump ACTION MODE`n`n" fillWithSpaces("Switch Channel", 28) " -  0..9`n"
	for it in items
		menuText .= fillWithSpaces(it.caption, 28) " -  " it.key "`n"
	m.mono := RTrim(menuText, "`n"), Hud.Render(m), snap(themeMode "-menu")
	cf := Hud.NewState(), cf.mode := "confirm", cf.mono := TXT.TIP_delallprompt, cf.keys := "Y   N"
	Hud.Render(cf), snap(themeMode "-confirm")
	Hud.Hide()
	Toast.Show("Transferred to Clipjump {Default}", 0, "info", "a")
	Toast.Show("Clip skipped (excluded by the app)", 0, "warn", "b")
	Toast.Show("Both Clipboards were synced. Success !", 0, "info", "c")
	Sleep 400
	pToken := Gdip_Startup()
	MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
	pBitmap := Gdip_BitmapFromScreen((r - 360) "|" (b - 260) "|360|260")
	Gdip_SaveBitmapToFile(pBitmap, A_ScriptDir "\out\toast-" themeMode ".png")
	Gdip_DisposeImage(pBitmap), Gdip_Shutdown(pToken)
	Toast.Hide("a"), Toast.Hide("b"), Toast.Hide("c")
	Sleep 200
}
FileAppend("done`n", "*")
ExitApp
