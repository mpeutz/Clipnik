; Theme.ahk - palette, Windows dark/light detection, and helpers that apply the theme to native Gui windows.
;
;   Theme.Init(mode, accent) mode: "system" | "dark" | "light"   (from [Main] Theme in settings.ini)
;                           accent: "" follows the Windows accent, "RRGGBB" is a fixed custom accent ([Main] Accent)
;   Theme.IsDark            current effective mode
;   Theme.Palette           Map of RGB integers: bg, surface, surfaceAlt, border, text, muted, accent, accentText, danger
;   Theme.Hex(name)         "RRGGBB" string for a palette entry (Gui.BackColor / c options)
;   Theme.OnChange(fn)      fn() is called after the Windows theme changes (WM_SETTINGCHANGE "ImmersiveColorSet")
;   Theme.ApplyToGui(g, corner) BackColor, dark title bar, rounded corners, border color, base font
;   Theme.StyleControl(ctl)  dark-mode visual styles for Edit/Button/ListBox/ListView/ComboBox controls
;   Theme.AddLink(g, opts, text, fn)  accent-colored underlined Text that acts as a link
;   Theme.Section(g, x, y, w, text)   muted uppercase header with a 1px rule; returns [label, rule]
;   Theme.Tip(ctl, text)    hover tooltip for a control (one tooltips_class32 per window)
;   Theme.PickColor(rgb, ownerHwnd)   Windows color dialog; returns an RGB integer or ""
;   Theme.Scale             A_ScreenDPI / 96, for windows created with -DPIScale (HUD, toasts)
;   Theme.CssVars()         the palette as CSS custom properties (for the WebView2 windows)

class Theme {
	static Mode := "system"
	static CustomAccent := ""
	static IsDark := false
	static Accent := 0x0078D4
	static WindowsAccent := 0x0078D4
	static Palette := Map()
	static Scale := A_ScreenDPI / 96
	static FontName := "Segoe UI"
	static listeners := []
	static watching := false

	static Init(mode := "system", accent := "") {
		Theme.Mode := (mode = "dark" || mode = "light") ? mode : "system"
		Theme.CustomAccent := Theme.ValidHex(accent) ? StrUpper(accent) : ""
		Theme.FontName := Theme.FontExists("Segoe UI Variable Text") ? "Segoe UI Variable Text" : "Segoe UI"
		Theme.Detect()
		Theme.Watch()
	}

	static SetMode(mode, accent := "") {
		Theme.Init(mode, accent)
		Theme.Notify()
	}

	static ValidHex(v) => RegExMatch(v, "^[0-9A-Fa-f]{6}$") ? true : false

	static Detect() {
		dark := false
		if (Theme.Mode = "dark")
			dark := true
		else if (Theme.Mode = "light")
			dark := false
		else {
			try dark := !RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme", 1)
		}
		Theme.IsDark := dark
		accent := 0x0078D4
		try {
			abgr := RegRead("HKCU\Software\Microsoft\Windows\DWM", "AccentColor")
			accent := ((abgr & 0xFF) << 16) | (abgr & 0xFF00) | ((abgr >> 16) & 0xFF)
		}
		Theme.WindowsAccent := accent
		if Theme.CustomAccent
			accent := Integer("0x" Theme.CustomAccent)
		Theme.Accent := accent
		p := Map()
		if dark {
			p["bg"] := 0x202020, p["surface"] := 0x2B2B2B, p["surfaceAlt"] := 0x363636, p["border"] := 0x3F3F3F
			p["text"] := 0xF0F0F0, p["muted"] := 0x9A9A9A, p["danger"] := 0xE5484D
		} else {
			p["bg"] := 0xF3F3F3, p["surface"] := 0xFFFFFF, p["surfaceAlt"] := 0xEDEDED, p["border"] := 0xD9D9D9
			p["text"] := 0x1B1B1B, p["muted"] := 0x6B6B6B, p["danger"] := 0xC42B1C
		}
		p["accent"] := Theme.CustomAccent ? accent : Theme.LegibleAccent(accent, dark)
		p["accentText"] := Theme.Luminance(p["accent"]) > 0.45 ? 0x000000 : 0xFFFFFF
		Theme.Palette := p
	}

	; brightens a dark accent for dark backgrounds, darkens a pale one for light backgrounds
	static LegibleAccent(rgb, dark) {
		lum := Theme.Luminance(rgb)
		if (dark && lum < 0.25)
			return Theme.Mix(rgb, 0xFFFFFF, 0.35)
		if (!dark && lum > 0.6)
			return Theme.Mix(rgb, 0x000000, 0.35)
		return rgb
	}

	static Luminance(rgb) {
		r := ((rgb >> 16) & 0xFF) / 255, g := ((rgb >> 8) & 0xFF) / 255, b := (rgb & 0xFF) / 255
		return 0.2126 * r + 0.7152 * g + 0.0722 * b
	}

	static Mix(a, b, t) {
		ch(sa, sb) => Round(sa + (sb - sa) * t)
		return (ch((a >> 16) & 0xFF, (b >> 16) & 0xFF) << 16) | (ch((a >> 8) & 0xFF, (b >> 8) & 0xFF) << 8) | ch(a & 0xFF, b & 0xFF)
	}

	static Hex(name) => Format("{:06X}", Theme.Palette[name])

	; COLORREF (BGR) for DllCalls
	static Bgr(name) {
		rgb := Theme.Palette[name]
		return ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF)
	}

	static OnChange(fn) {
		Theme.listeners.Push(fn)
	}

	static Notify() {
		for fn in Theme.listeners
			try fn()
	}

	static Watch() {
		if Theme.watching
			return
		Theme.watching := true
		OnMessage(0x1A, Theme_OnSettingChange)
	}

	; corner: 1 = none, 2 = round, 3 = small round (DWMWA_WINDOW_CORNER_PREFERENCE)
	static ApplyToGui(g, corner := 2, border := false) {
		g.BackColor := Theme.Hex("bg")
		g.SetFont("s10 c" Theme.Hex("text"), Theme.FontName)
		Theme.ApplyToHwnd(g.Hwnd, corner, border)
	}

	static ApplyToHwnd(hwnd, corner := 2, border := false) {
		dark := Theme.IsDark ? 1 : 0
		try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 20, "Int*", dark, "UInt", 4)   ; DWMWA_USE_IMMERSIVE_DARK_MODE
		try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 33, "Int*", corner, "UInt", 4)  ; DWMWA_WINDOW_CORNER_PREFERENCE
		if border
			try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 34, "Int*", Theme.Bgr("border"), "UInt", 4) ; DWMWA_BORDER_COLOR
	}

	; Applies dark-mode visual styles to a control; call after g.Add.
	static StyleControl(ctl) {
		kind := ctl.Type
		styleName := Theme.IsDark ? "DarkMode_Explorer" : "Explorer"
		if (kind = "DDL" || kind = "ComboBox")
			styleName := Theme.IsDark ? "DarkMode_CFD" : "CFD"
		if (kind = "Edit" || kind = "Button" || kind = "ListBox" || kind = "ListView" || kind = "TreeView" || kind = "DDL" || kind = "ComboBox" || kind = "CheckBox" || kind = "Radio")
			try DllCall("uxtheme\SetWindowTheme", "Ptr", ctl.Hwnd, "Str", styleName, "Ptr", 0)
		if (kind = "ListView") {
			hdr := SendMessage(0x101F, 0, 0, ctl.Hwnd)  ; LVM_GETHEADER
			if hdr
				try DllCall("uxtheme\SetWindowTheme", "Ptr", hdr, "Str", Theme.IsDark ? "DarkMode_ItemsView" : "ItemsView", "Ptr", 0)
			Theme.SubclassListView(ctl.Hwnd)
		}
		if (kind = "UpDown")
			try DllCall("uxtheme\SetWindowTheme", "Ptr", ctl.Hwnd, "Str", styleName, "Ptr", 0)
		if (kind = "Edit" || kind = "ListBox" || kind = "ListView" || kind = "TreeView") {
			try ctl.Opt("Background" Theme.Hex("surface") " c" Theme.Hex("text"))
		}
		return ctl
	}

	; g.Add wrapper that styles the control
	static Add(g, type, opts := "", text := "") {
		ctl := (text = "") ? g.Add(type, opts) : g.Add(type, opts, text)
		return Theme.StyleControl(ctl)
	}

	; The header child sends NM_CUSTOMDRAW to the ListView, so the ListView is subclassed to recolor header text.
	static SubclassListView(hwnd) {
		static cb := CallbackCreate(Theme_ListViewProc, "F", 6)
		DllCall("comctl32\SetWindowSubclass", "Ptr", hwnd, "Ptr", cb, "Ptr", 1, "Ptr", 0)
	}

	static AddLink(g, opts, text, fn) {
		g.SetFont("underline c" Theme.Hex("accent"))
		ctl := g.Add("Text", opts " +0x100", text)
		g.SetFont("norm c" Theme.Hex("text"))
		ctl.OnEvent("Click", fn)
		return ctl
	}

	static Section(g, x, y, w, text) {
		g.SetFont("s8 bold c" Theme.Hex("muted"))
		lbl := g.Add("Text", "x" x " y" y " w" w " h16 +0x200", StrUpper(text))
		g.SetFont("s10 norm c" Theme.Hex("text"))
		rule := g.Add("Progress", "x" x " y" (y + 20) " w" w " h1 -Theme Background" Theme.Hex("border") " c" Theme.Hex("border"), 100)
		return [lbl, rule]
	}

	; One tooltip window per Gui, TTF_SUBCLASS so no message handling is needed.
	static Tip(ctl, text) {
		static tips := Map()
		if (text = "")
			return
		g := ctl.Gui
		if !tips.Has(g.Hwnd) {
			tt := DllCall("CreateWindowEx", "UInt", 0x8, "Str", "tooltips_class32", "Ptr", 0, "UInt", 0x80000003, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr", g.Hwnd, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
			DllCall("uxtheme\SetWindowTheme", "Ptr", tt, "Str", Theme.IsDark ? "DarkMode_Explorer" : "Explorer", "Ptr", 0)
			SendMessage(0x418, 0, 360, tt)   ; TTM_SETMAXTIPWIDTH
			tips[g.Hwnd] := tt
		}
		tt := tips[g.Hwnd]
		ti := Buffer(A_PtrSize = 8 ? 72 : 48, 0)
		NumPut("UInt", ti.Size, ti, 0)
		NumPut("UInt", 0x11, ti, 4)                       ; TTF_IDISHWND | TTF_SUBCLASS
		NumPut("Ptr", g.Hwnd, ti, 8)
		NumPut("Ptr", ctl.Hwnd, ti, 8 + A_PtrSize)
		NumPut("Ptr", StrPtr(text), ti, 8 + 2 * A_PtrSize + 16 + A_PtrSize)
		SendMessage(0x432, 0, ti, tt)                       ; TTM_ADDTOOLW
		tips[g.Hwnd "text" ctl.Hwnd] := text                ; keep the string alive
	}

	; comdlg32 ChooseColor; returns RGB or "" when cancelled
	static PickColor(rgb := 0, owner := 0) {
		static custom := Buffer(64, 0)
		cc := Buffer(A_PtrSize = 8 ? 72 : 36, 0)
		NumPut("UInt", cc.Size, cc, 0)
		NumPut("Ptr", owner, cc, A_PtrSize)
		NumPut("UInt", Theme.ToBgr(rgb), cc, 3 * A_PtrSize)
		NumPut("Ptr", custom.Ptr, cc, 4 * A_PtrSize)
		NumPut("UInt", 0x3, cc, 5 * A_PtrSize)               ; CC_RGBINIT | CC_FULLOPEN
		if !DllCall("comdlg32\ChooseColorW", "Ptr", cc)
			return ""
		return Theme.ToBgr(NumGet(cc, 3 * A_PtrSize, "UInt"))
	}

	static ToBgr(rgb) => ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF)

	static FontExists(name) {
		static cache := Map()
		if cache.Has(name)
			return cache[name]
		hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
		lf := Buffer(92, 0)      ; LOGFONTW
		NumPut("UChar", 1, lf, 23) ; lfCharSet = DEFAULT_CHARSET
		StrPut(name, lf.Ptr + 28, 32, "UTF-16")
		found := 0
		cb := CallbackCreate((lpelfe, lpntme, fontType, lParam) => (found := 1, 0), "F", 4)
		DllCall("EnumFontFamiliesExW", "Ptr", hdc, "Ptr", lf, "Ptr", cb, "Ptr", 0, "UInt", 0)
		CallbackFree(cb)
		DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
		return cache[name] := found
	}

	static CssVars() {
		s := ""
		for k, v in Theme.Palette
			s .= "--" k ":#" Format("{:06X}", v) ";"
		return s
	}

	; Work area (physical pixels) of the monitor containing point x,y
	static WorkAreaAt(x, y, &l, &t, &r, &b) {
		loop MonitorGetCount() {
			MonitorGet(A_Index, &ml, &mt, &mr, &mb)
			if (x >= ml && x < mr && y >= mt && y < mb) {
				MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
				return A_Index
			}
		}
		MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
		return MonitorGetPrimary()
	}
}

Theme_OnSettingChange(wParam, lParam, msg, hwnd) {
	if (lParam && StrGet(lParam) = "ImmersiveColorSet") {
		Theme.Detect()
		SetTimer(Theme_NotifyLater, -50)
	}
}

Theme_NotifyLater() {
	Theme.Notify()
}

Theme_ListViewProc(hwnd, msg, wParam, lParam, id, ref) {
	static NM_CUSTOMDRAW := -12, CDDS_PREPAINT := 1, CDDS_ITEMPREPAINT := 0x10001, CDRF_NOTIFYITEMDRAW := 0x20, CDRF_DODEFAULT := 0
	if (msg = 0x4E && NumGet(lParam, A_PtrSize * 2, "Int") = NM_CUSTOMDRAW) {
		stage := NumGet(lParam, A_PtrSize * 3, "UInt")
		if (stage = CDDS_PREPAINT)
			return CDRF_NOTIFYITEMDRAW
		if (stage = CDDS_ITEMPREPAINT) {
			DllCall("SetTextColor", "Ptr", NumGet(lParam, A_PtrSize * 4, "Ptr"), "UInt", Theme.Bgr("text"))
			return CDRF_DODEFAULT
		}
	}
	return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
}
