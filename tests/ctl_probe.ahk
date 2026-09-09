; Probe: which Win32 controls render legibly with the dark palette. Saves tests\out\ctl-probe-dark.png / -light.png.
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\lib\v2compat.ahk
#Include ..\lib\vendor\Gdip_All.ahk
#Include ..\src\ui\native\Theme.ahk
SetWorkingDir A_ScriptDir "\.."
for mode in ["dark", "light"] {
	Theme.Init(mode)
	g := Gui("+AlwaysOnTop", "probe")
	Theme.ApplyToGui(g)
	t := Theme.Hex("text"), m := Theme.Hex("muted"), s := Theme.Hex("surface"), a := Theme.Hex("surfaceAlt")
	g.SetFont("s10 c" t, Theme.FontName)
	Theme.Add(g, "CheckBox", "x16 y16 Checked", "Checkbox with c color")
	Theme.Add(g, "CheckBox", "x16 y+8", "Unchecked one")
	g.Add("CheckBox", "x16 y+8 Checked -Theme", "Checkbox -Theme")
	Theme.Add(g, "Radio", "x16 y+8 Checked", "Radio")
	Theme.Add(g, "Edit", "x16 y+12 w200", "Edit Background surface")
	e := Theme.Add(g, "Edit", "x16 y+8 w200 -E0x200 +Border", "Edit no client edge")
	e.Opt("Background" a)
	Theme.Add(g, "DDL", "x16 y+8 w200 Choose1", ["Follow Windows", "Dark", "Light"])
	Theme.Add(g, "ComboBox", "x16 y+8 w200", ["Normal", "High"])
	Theme.Add(g, "Button", "x16 y+12 w90", "OK")
	Theme.Add(g, "Button", "x+8 yp w90 Disabled", "Apply")
	g.Add("Text", "x16 y+12 w200 h32 +0x200 Background" a, "  Text with Background")
	g.Add("Progress", "x16 y+4 w3 h16 -Theme Background" Theme.Hex("accent") " c" Theme.Hex("accent"), 100)
	g.SetFont("s9 c" m)
	g.Add("Text", "x16 y+8", "muted hint text")
	g.SetFont("s10 c" t)
	Theme.Add(g, "ListBox", "x240 y16 w160 r6 -E0x200 +Border", ["General", "History", "Shortcuts"])
	lv := Theme.Add(g, "ListView", "x240 y+8 w160 r4 -E0x200 +Border", ["Class", "Tags"])
	lv.Add("", "Notepad", "x")
	Theme.Add(g, "Edit", "x240 y+8 w160 Number", "20")
	ud := g.Add("UpDown", "Range1-100", 20)
	DllCall("uxtheme\SetWindowTheme", "Ptr", ud.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
	g.SetFont("s10 underline c" Theme.Hex("accent"))
	g.Add("Text", "x240 y+8", "Open settings folder")
	g.SetFont("s10 norm c" t)
	cb := CallbackCreate(probeSubclass, "F", 6)
	DllCall("comctl32\SetWindowSubclass", "Ptr", lv.Hwnd, "Ptr", cb, "Ptr", 1, "Ptr", 0)
	g.Show("w420 h360")
	Sleep 600
	WinGetPos(&x, &y, &w, &h, g.Hwnd)
	p := Gdip_Startup(), b := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
	Gdip_SaveBitmapToFile(b, A_ScriptDir "\out\ctl-probe-" mode ".png"), Gdip_DisposeImage(b), Gdip_Shutdown(p)
	g.Destroy()
}
ExitApp

; ListView subclass: paints header text with the palette text color (NM_CUSTOMDRAW from the header child)
probeSubclass(hwnd, msg, wParam, lParam, id, ref) {
	static NM_CUSTOMDRAW := -12, CDDS_PREPAINT := 1, CDDS_ITEMPREPAINT := 0x10001, CDRF_NOTIFYITEMDRAW := 0x20, CDRF_DODEFAULT := 0
	if (msg = 0x4E) {
		code := NumGet(lParam, A_PtrSize * 2, "Int")
		if (code = NM_CUSTOMDRAW) {
			stage := NumGet(lParam, A_PtrSize * 3, "UInt")
			if (stage = CDDS_PREPAINT)
				return CDRF_NOTIFYITEMDRAW
			if (stage = CDDS_ITEMPREPAINT) {
				hdc := NumGet(lParam, A_PtrSize * 4, "Ptr")
				DllCall("SetTextColor", "Ptr", hdc, "UInt", Theme.Bgr("text"))
				return CDRF_DODEFAULT
			}
		}
	}
	return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
}
