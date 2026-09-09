; Theme.ahk - palette, Windows dark/light detection, and helpers that apply the theme to native Gui windows.
;
;   Theme.Init(mode)        mode: "system" | "dark" | "light"   (from [Main] Theme in settings.ini)
;   Theme.IsDark            current effective mode
;   Theme.Palette           Map of RGB integers: bg, surface, surfaceAlt, border, text, muted, accent, accentText, danger
;   Theme.Hex(name)         "RRGGBB" string for a palette entry (Gui.BackColor / c options)
;   Theme.OnChange(fn)      fn() is called after the Windows theme changes (WM_SETTINGCHANGE "ImmersiveColorSet")
;   Theme.ApplyToGui(g, corner) BackColor, dark title bar, rounded corners, border color, base font
;   Theme.StyleControl(ctl)  dark-mode visual styles for Edit/Button/ListBox/ListView/ComboBox controls
;   Theme.Scale             A_ScreenDPI / 96, for windows created with -DPIScale (HUD, toasts)
;   Theme.CssVars()         the palette as CSS custom properties (for the WebView2 windows)

class Theme {
	static Mode := "system"
	static IsDark := false
	static Accent := 0x0078D4
	static Palette := Map()
	static Scale := A_ScreenDPI / 96
	static FontName := "Segoe UI"
	static listeners := []
	static watching := false

	static Init(mode := "system") {
		Theme.Mode := (mode = "dark" || mode = "light") ? mode : "system"
		Theme.FontName := Theme.FontExists("Segoe UI Variable Text") ? "Segoe UI Variable Text" : "Segoe UI"
		Theme.Detect()
		Theme.Watch()
	}

	static SetMode(mode) {
		Theme.Init(mode)
		Theme.Notify()
	}

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
		Theme.Accent := accent
		p := Map()
		if dark {
			p["bg"] := 0x202020, p["surface"] := 0x2B2B2B, p["surfaceAlt"] := 0x363636, p["border"] := 0x3F3F3F
			p["text"] := 0xF0F0F0, p["muted"] := 0x9A9A9A, p["danger"] := 0xE5484D
		} else {
			p["bg"] := 0xF3F3F3, p["surface"] := 0xFFFFFF, p["surfaceAlt"] := 0xEDEDED, p["border"] := 0xD9D9D9
			p["text"] := 0x1B1B1B, p["muted"] := 0x6B6B6B, p["danger"] := 0xC42B1C
		}
		p["accent"] := Theme.LegibleAccent(accent, dark)
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
		}
		if (kind = "Edit" || kind = "ListBox" || kind = "ListView" || kind = "TreeView") {
			try ctl.Opt("Background" Theme.Hex("surface") " c" Theme.Hex("text"))
		}
		return ctl
	}

	; g.Add wrapper that styles the control
	static Add(g, type, opts := "", text := "") {
		ctl := (text is Array) ? g.Add(type, opts, text) : g.Add(type, opts, text)
		return Theme.StyleControl(ctl)
	}

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
