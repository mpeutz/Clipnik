; The card must come back to the topmost band every time it is shown. An external window manager
; (PowerToys Always On Top, FancyZones, Groupy, a virtual-desktop switcher) can push a window out of
; that band with SetWindowPos while leaving WS_EX_TOPMOST set; the reusable card would then render
; behind every ordinary window for the rest of the session. Standalone: stubs the Clipnik globals the
; modules touch, exactly as hud_demo does.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\zorder.ahk
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\lib\v2compat.ahk
#Include ..\src\ui\native\Theme.ahk
#Include ..\src\ui\native\Toast.ahk
#Include ..\src\ui\native\Hud.ahk
#Include ..\src\core\cliptype.ahk
#Include ..\lib\translations.ahk
SetWorkingDir A_ScriptDir "\.."
FileEncoding "UTF-8"
DetectHiddenWindows true
global STORE := CJMap(), CJGUI := Map(), ACTIONS := CJMap()
global ini_pstMode_X := "", ini_pstMode_Y := "", ini_LANG := "english"
global CDS := Map()
AddClipPref(*) => 0
global CN := CJMap("Name", "Default", "NG", 0), realclipno := 3, CURSAVE := 40, curPformat := "", fixStatus := "", halfClip := ""
global temp_clipboard := "", THUMBS_dir := "cache/thumbs", TEMPSAVE := 1, realActive := 1, SPM := CJMap(), ctrlRef := ""
global VAULT := CJMap(), LOCK := CJMap()
global TXT := Translations_load("languages/english.txt")
global PROGNAME := "Clipnik"
hkZ(key, fn, status := 1) => Hotkey(key, fn, status ? "On" : "Off")
clipPref(ch, clip, name) => (name = "Tags") ? "" : ""
GetClipboardFormat(type := 1) => "[Text]"
fillWithSpaces(text := "", limit := 35) {
	r := ""
	loop limit - StrLen(text)
		r .= A_Space
	return text r
}

fails := 0
check(cond, msg) {
	global fails
	FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
	if !cond
		fails++
}

; visible, non-cloaked, ordinary (non-topmost) windows sitting above this one: 0 means the window
; really is in the topmost band, whatever its style bits claim
nonTopmostAbove(target) {
	n := 0
	w := DllCall("GetTopWindow", "Ptr", 0, "Ptr")
	while w {
		if (w = target)
			return n
		if DllCall("IsWindowVisible", "Ptr", w) && !cloaked(w) {
			ex := DllCall("GetWindowLongPtr", "Ptr", w, "Int", -20, "Ptr")
			t := ""
			try t := WinGetTitle("ahk_id " w)
			r := Buffer(16, 0), DllCall("GetWindowRect", "Ptr", w, "Ptr", r)
			area := (NumGet(r, 8, "Int") - NumGet(r, 0, "Int")) * (NumGet(r, 12, "Int") - NumGet(r, 4, "Int"))
			if !(ex & 0x8) && t != "" && area > 10000
				n++
		}
		w := DllCall("GetWindow", "Ptr", w, "UInt", 2, "Ptr")
	}
	return -1
}

; is a above b in the z-order?
isAbove(a, b) {
	w := DllCall("GetTopWindow", "Ptr", 0, "Ptr")
	while w {
		if (w = a)
			return true
		if (w = b)
			return false
		w := DllCall("GetWindow", "Ptr", w, "UInt", 2, "Ptr")
	}
	return false
}

cloaked(h) {
	v := 0
	try DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", h, "UInt", 14, "Int*", &v, "UInt", 4)
	return v
}

showCard() {
	s := Hud.NewState()
	s.channel := "Default", s.index := 3, s.total := 40, s.format := "TEXT", s.text := "z-order regression"
	Hud.Render(s)
	Sleep 150
}

Theme.Init("dark")
DllCall("GDI32.DLL\AddFontResourceEx", "Str", A_WorkingDir "\icons\lucide.ttf", "UInt", 0x10, "Int", 0)
Hud.Init()
MouseMove(400, 300)

; an ordinary window to be pushed behind, and to push the card behind
victim := Gui("+Resize", "cj-zorder-victim")
victim.Add("Text", "w360 h120", "z-order test window")
victim.Show("x60 y60 w380 h160")
WinWaitActive("cj-zorder-victim", , 3)
Sleep 200

showCard()
check(nonTopmostAbove(Hud.g.Hwnd) = 0, "card shows in the topmost band")

; what an external window manager does to the card itself: place it directly behind an ordinary
; window (SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE). Windows clears WS_EX_TOPMOST for this shape.
Hud.Hide()
DllCall("SetWindowPos", "Ptr", Hud.g.Hwnd, "Ptr", victim.Hwnd, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
showCard()
above := nonTopmostAbove(Hud.g.Hwnd)
check(above = 0, "card returns to the band after being demoted directly (" above " ordinary windows above it)")

; and the shape seen in the field: the OWNER is pushed down, which drags the owned card with it while
; leaving WS_EX_TOPMOST set on the card - the state that makes the style bits lie
Hud.Hide()
DllCall("SetWindowPos", "Ptr", A_ScriptHwnd, "Ptr", victim.Hwnd, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
showCard()
above := nonTopmostAbove(Hud.g.Hwnd)
check(above = 0, "card returns to the band after its owner was demoted (" above " ordinary windows above it)")

; and it must not steal the top of the band from another topmost popup of ours that is legitimately
; above the card (the Action Ring while it is open)
peer := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x08000000", "cj-zorder-peer")
peer.Add("Text", "w200 h40", "topmost peer")
peer.Show("NoActivate x500 y60 w220 h60")
Sleep 150
showCard()
check(nonTopmostAbove(Hud.g.Hwnd) = 0, "card is still in the band with a topmost peer around")
check(nonTopmostAbove(peer.Hwnd) = 0 && isAbove(peer.Hwnd, Hud.g.Hwnd), "a topmost peer above the card stays above it")
peer.Destroy()

Hud.Hide()
victim.Destroy()
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
