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
	static SystemIsDark := false   ; the taskbar's theme, which the tray icon answers to
	static Accent := 0x0078D4
	static WindowsAccent := 0x0078D4
	static Palette := Map()
	static Scale := A_ScreenDPI / 96
	static FontName := "Segoe UI"
	static IconFont := "lucide"        ; icons/lucide.ttf (ISC), registered privately at startup
	; Lucide codepoints (font/codepoints.json of lucide-static); Theme.Icon(name) returns the glyph
	static Icons := Map("settings", 57684, "history", 57845, "keyboard", 57988, "layout-grid", 57599, "palette", 57821, "sliders-horizontal", 58010
		, "eye-off", 57531, "ban", 57425, "chevron-right", 57455, "check", 57452, "pin", 57945, "search", 57681, "plus", 57661
		, "arrow-up", 57418, "arrow-down", 57410, "chevron-down", 57453, "clipboard", 57477, "wrench", 57777, "x", 57778
		, "shield-check", 57855, "loader", 57609, "tag", 57727, "image", 57590, "trash-2", 57742, "zap", 57780, "circle-help", 57474
		, "scissors", 57678, "copy", 57502, "clipboard-check", 57881, "file", 57536, "folder", 57559)
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
		; the tray icon sits on the taskbar, which has its own setting and ignores both AppsUseLightTheme
		; and the user's choice of theme for Clipnik's own windows
		sysDark := dark
		try sysDark := !RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "SystemUsesLightTheme", 1)
		Theme.SystemIsDark := sysDark
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
			p["text"] := 0xF0F0F0, p["muted"] := 0x9A9A9A, p["danger"] := 0xE5484D, p["warn"] := 0xE0A526
		} else {
			p["bg"] := 0xF3F3F3, p["surface"] := 0xFFFFFF, p["surfaceAlt"] := 0xEDEDED, p["border"] := 0xD9D9D9
			p["text"] := 0x1B1B1B, p["muted"] := 0x6B6B6B, p["danger"] := 0xC42B1C, p["warn"] := 0xB07A00
		}
		p["accent"] := Theme.CustomAccent ? accent : Theme.LegibleAccent(accent, dark)
		p["accentText"] := Theme.Luminance(p["accent"]) > 0.45 ? 0x000000 : 0xFFFFFF
		p["accentSoft"] := Theme.Mix(p["accent"], p["surface"], 0.82)
		Theme.Palette := p
	}

	; The tint for the tray icon. It answers to the TASKBAR's theme, not to the app palette: Clipnik can
	; be in light mode, and a custom accent skips LegibleAccent altogether, so the palette accent can be
	; a mid-dark blue sitting on a near-black taskbar. Steps the accent toward white (dark taskbar) or
	; black (light one) until it clears TrayContrast, so the hue is kept and only the legibility moves.
	static TrayContrast := 4.5
	static TrayBgDark := 0x202020, TrayBgLight := 0xF3F3F3

	static TrayTint(accent?, dark?) {
		accent := accent ?? Theme.Accent
		dark := dark ?? Theme.SystemIsDark
		bg := dark ? Theme.TrayBgDark : Theme.TrayBgLight
		toward := dark ? 0xFFFFFF : 0x000000
		tint := accent, t := 0
		while (t < 1 && Theme.ContrastRatio(tint, bg) < Theme.TrayContrast) {
			t := Min(t + 0.05, 1)
			tint := Theme.Mix(accent, toward, t)
		}
		return tint
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

	; WCAG relative luminance, with the sRGB channels linearized. Luminance() above is the cheap
	; unlinearized version and stays that way: it answers "does this look bright", which is all the
	; palette needs, but it is too optimistic about saturated blues to threshold a contrast ratio on.
	static LinChannel(c) {
		v := c / 255
		return (v <= 0.03928) ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4
	}

	static RelLuminance(rgb) {
		return 0.2126 * Theme.LinChannel((rgb >> 16) & 0xFF) + 0.7152 * Theme.LinChannel((rgb >> 8) & 0xFF) + 0.0722 * Theme.LinChannel(rgb & 0xFF)
	}

	static ContrastRatio(a, b) {
		la := Theme.RelLuminance(a), lb := Theme.RelLuminance(b)
		return (Max(la, lb) + 0.05) / (Min(la, lb) + 0.05)
	}

	static Hex(name) => Format("{:06X}", Theme.Palette[name])

	static HasIcons() => Theme.FontExists(Theme.IconFont)

	static Icon(name) => Theme.Icons.Has(name) ? Chr(Theme.Icons[name]) : ""

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
		OnMessage(0x4E, Theme_OnNotify)      ; WM_NOTIFY: custom draw for buttons and check boxes
		OnMessage(0x84, Theme_OnNcHitTest)   ; the thick frame that earns popups their shadow must not resize them
		OnMessage(0x83, Theme_OnNcCalcSize)  ; ...and must not take any space: the client fills the whole window
	}

	; ---------- custom-drawn buttons and check boxes ----------
	; The system dark theme paints a fixed light-blue check and bright button borders; NM_CUSTOMDRAW with
	; CDRF_SKIPDEFAULT lets the controls stay native (keyboard, Tab, events) while the theme paints them.
	static drawn := Map()

	static RegisterDraw(ctl, kind, style := "") {
		primary := (kind = "button") && ((WinGetStyle(ctl.Hwnd) & 0xF) = 1)   ; BS_DEFPUSHBUTTON at creation = the primary action
		Theme.drawn[ctl.Hwnd] := {kind: kind, primary: primary, ctl: ctl, fill: style ? style.fill : "", text: style ? style.text : ""}
	}

	; A pill: a Button drawn as a rounded capsule with a fixed fill and text color (no hover or focus states).
	; fill / text are palette names ("accent", "surfaceAlt", ...). Not a tab stop, so it never takes focus.
	static AddPill(g, opts, text, fill := "surfaceAlt", color := "text", swatch := "") {
		ctl := g.Add("Button", opts " -TabStop", text)
		try DllCall("uxtheme\SetWindowTheme", "Ptr", ctl.Hwnd, "Str", Theme.IsDark ? "DarkMode_Explorer" : "Explorer", "Ptr", 0)
		Theme.RegisterDraw(ctl, "pill", {fill: fill, text: color, swatch: swatch})
		return ctl
	}

	static SetPill(ctl, fill, color, swatch := "") {
		if Theme.drawn.Has(ctl.Hwnd) {
			d := Theme.drawn[ctl.Hwnd]
			d.fill := fill, d.text := color, d.swatch := swatch
			ctl.Redraw()
		}
	}

	static DrawPill(d, hdc, rc, state) {
		p := Theme.Palette
		h := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
		fill := p.Has(d.fill) ? p[d.fill] : p["surfaceAlt"], color := p.Has(d.text) ? p[d.text] : p["text"]
		Theme.PaintRoundRect(hdc, rc, fill, fill, Theme.RgbFromGui(d.ctl.Gui), h // 2)
		trc := rc
		if (d.HasProp("swatch") && d.swatch != "") {
			s := Round(10 * Theme.Scale), l := NumGet(rc, 0, "Int") + Round(8 * Theme.Scale), t := NumGet(rc, 4, "Int") + (h - s) // 2
			box := Buffer(16, 0), NumPut("Int", l, "Int", t, "Int", l + s, "Int", t + s, box)
			Theme.PaintRoundRect(hdc, box, d.swatch, Theme.Mix(d.swatch, 0xFFFFFF, 0.3), fill, Round(3 * Theme.Scale))
			trc := Buffer(16, 0), NumPut("Int", l + s, "Int", NumGet(rc, 4, "Int"), "Int", NumGet(rc, 8, "Int"), "Int", NumGet(rc, 12, "Int"), trc)
		}
		Theme.PaintText(hdc, d.ctl, trc, color, 0x1 | 0x4 | 0x20 | 0x100000, 0)
	}

	; A borderless popup with a DWM drop shadow, rounded corners and uniform translucency (toasts, the paste card,
	; the tray card): WS_THICKFRAME plus a 1px frame extension is what makes DWM draw the shadow.
	static Popup(g, alpha := 245) {
		g.Opt("+0x40000")
		m := Buffer(16, 0), NumPut("Int", 1, m, 12)
		try DllCall("dwmapi\DwmExtendFrameIntoClientArea", "Ptr", g.Hwnd, "Ptr", m)
		Theme.ApplyToHwnd(g.Hwnd, 2, true)
		Theme.popups[g.Hwnd] := true
		DllCall("SetWindowPos", "Ptr", g.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x37) ; SWP_FRAMECHANGED: recalc the client
		if (alpha < 255)
			try WinSetTransparent(alpha, g.Hwnd)
	}
	static popups := Map()

	; shows a popup with an OUTER size of w x h; Gui.Show would add the (now invisible) frame to the client size
	static ShowPopup(g, x, y, w, h, activate := false) {
		g.Show((activate ? "" : "NoActivate ") "x" x " y" y " w" w " h" h)
		WinMove(x, y, w, h, g.Hwnd)
		Theme.Raise(g.Hwnd)
	}

	; Puts a window back in the topmost band. The cards are created once and shown again and again, so
	; one SetWindowPos from an external window manager - PowerToys Always On Top, FancyZones, Groupy, a
	; virtual-desktop switcher - is enough to leave them drawing behind every ordinary window for the
	; rest of the session. Windows does not always clear WS_EX_TOPMOST when it moves a window out of
	; the band, so the style bits cannot be trusted; the real z-order is what gets asked.
	; Only a window that has actually fallen out is moved, so re-showing the card never jumps it over
	; another popup of ours that is legitimately above it (the Action Ring, say).
	static Raise(hwnd) {
		if Theme.InTopmostBand(hwnd)
			return
		DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13) ; HWND_TOPMOST, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE
	}

	; true while every visible window above this one is itself topmost. Walking up stops at the first
	; ordinary window, so the common case (nothing moved us) costs a handful of GetWindow calls.
	static InTopmostBand(hwnd) {
		w := DllCall("GetWindow", "Ptr", hwnd, "UInt", 3, "Ptr")   ; GW_HWNDPREV: the window above
		while w {
			if DllCall("IsWindowVisible", "Ptr", w) && !(DllCall("GetWindowLongPtr", "Ptr", w, "Int", -20, "Ptr") & 0x8) {
				cloak := 0   ; a window parked on another virtual desktop is not really above anything
				try DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", w, "UInt", 14, "Int*", &cloak, "UInt", 4)
				if !cloak
					return false
			}
			w := DllCall("GetWindow", "Ptr", w, "UInt", 3, "Ptr")
		}
		return true
	}

	static UnregisterDraw(hwnd) {
		try Theme.drawn.Delete(hwnd)
	}

	; The app icon with its purple repainted in the accent: returns an HICON (cached per file, size and accent)
	; for TraySetIcon("HICON:*" h) and Picture controls. Falls back to 0 when anything goes wrong.
	; Works on the icon's own 32-bit color bitmap (GDI+'s HICON conversion drops the alpha channel and leaves a
	; dark fringe around anti-aliased edges).
	static iconCache := Map()
	static AccentIcon(path, size := 32, tint?) {
		if !Theme.Palette.Has("accent")   ; before Theme.Init the plain file is used
			return 0
		tint := tint ?? Theme.Palette["accent"]   ; the tray passes its own; title bars and About keep the app accent
		key := path "|" size "|" Format("{:06X}", tint)
		if Theme.iconCache.Has(key)
			return Theme.iconCache[key]
		h := 0, hdc := 0, src := 0, hbm := 0, mask := 0, color := 0
		ii := Buffer(8 + 3 * A_PtrSize, 0)   ; ICONINFO: fIcon, xHotspot, yHotspot, hbmMask, hbmColor
		try {
			src := DllCall("LoadImage", "Ptr", 0, "Str", path, "UInt", 1, "Int", size, "Int", size, "UInt", 0x10, "Ptr")  ; IMAGE_ICON, LR_LOADFROMFILE
			if src && DllCall("GetIconInfo", "Ptr", src, "Ptr", ii) {
				mask := NumGet(ii, 8 + A_PtrSize, "Ptr"), color := NumGet(ii, 8 + 2 * A_PtrSize, "Ptr")
				bmi := Buffer(40, 0)   ; BITMAPINFOHEADER, top-down 32 bpp
				NumPut("UInt", 40, "Int", size, "Int", -size, "UShort", 1, "UShort", 32, bmi)
				hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
				hbm := DllCall("CreateDIBSection", "Ptr", hdc, "Ptr", bmi, "UInt", 0, "Ptr*", &bits := 0, "Ptr", 0, "UInt", 0, "Ptr")
				if hbm && color && DllCall("GetDIBits", "Ptr", hdc, "Ptr", color, "UInt", 0, "UInt", size, "Ptr", bits, "Ptr", bmi, "UInt", 0) {
					Theme.Recolor(bits, size * size, tint)
					NumPut("Ptr", hbm, ii, 8 + 2 * A_PtrSize)
					h := DllCall("CreateIconIndirect", "Ptr", ii, "Ptr")   ; copies the bitmaps
				}
			}
		}
		if hdc
			DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
		for b in [mask, color, hbm]
			if b
				DllCall("DeleteObject", "Ptr", b)
		if src
			DllCall("DestroyIcon", "Ptr", src)
		return Theme.iconCache[key] := h
	}

	; repaints the icon's purple (body, lit crescent, shading) in rgb: every purple pixel takes the accent's hue and
	; saturation and keeps its lightness relative to the body purple, so the two tones survive. White and gray stay.
	; bits: count BGRA pixels. An icon without an alpha channel (all alpha 0) is recolored wherever its colors are.
	static Recolor(bits, count, rgb) {
		static bodyL := 0.6255   ; lightness of the body purple #8440FF
		acc := Theme.ToHsl(rgb)
		hasAlpha := false
		loop count
			if NumGet(bits, (A_Index - 1) * 4 + 3, "UChar") {
				hasAlpha := true
				break
			}
		loop count {
			p := bits + (A_Index - 1) * 4
			if hasAlpha && !NumGet(p, 3, "UChar")
				continue
			hsl := Theme.ToHsl((NumGet(p, 2, "UChar") << 16) | (NumGet(p, 1, "UChar") << 8) | NumGet(p, 0, "UChar"))
			if hsl[2] < 0.25 || hsl[1] < 230 || hsl[1] > 300   ; not purple
				continue
			l := hsl[3]
			nl := l <= bodyL ? acc[3] * l / bodyL : acc[3] + (1 - acc[3]) * (l - bodyL) / (1 - bodyL)
			c := Theme.FromHsl(acc[1], acc[2] * hsl[2], nl)
			NumPut("UChar", c & 0xFF, p, 0), NumPut("UChar", (c >> 8) & 0xFF, p, 1), NumPut("UChar", (c >> 16) & 0xFF, p, 2)
		}
	}

	; [hue 0-360, saturation 0-1, lightness 0-1] of an RGB integer
	static ToHsl(rgb) {
		r := ((rgb >> 16) & 0xFF) / 255, g := ((rgb >> 8) & 0xFF) / 255, b := (rgb & 0xFF) / 255
		mx := Max(r, g, b), mn := Min(r, g, b), l := (mx + mn) / 2, d := mx - mn
		if !d
			return [0, 0, l]
		s := d / (1 - Abs(2 * l - 1))
		h := mx = r ? Mod((g - b) / d + 6, 6) : mx = g ? (b - r) / d + 2 : (r - g) / d + 4
		return [h * 60, s, l]
	}

	static FromHsl(h, s, l) {
		c := (1 - Abs(2 * l - 1)) * s, x := c * (1 - Abs(Mod(h / 60, 2) - 1)), m := l - c / 2
		rgb := h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x]
		return (Round((rgb[1] + m) * 255) << 16) | (Round((rgb[2] + m) * 255) << 8) | Round((rgb[3] + m) * 255)
	}

	; frees a control's window (AHK has no per-control destroy) so rebuilding a Gui's controls leaves no orphans
	static Discard(ctl) {
		try Theme.UnregisterDraw(ctl.Hwnd)
		try DllCall("DestroyWindow", "Ptr", ctl.Hwnd)
	}

	static DrawButton(d, hdc, rc, state) {
		static CDIS_SELECTED := 1, CDIS_DISABLED := 4, CDIS_FOCUS := 0x10, CDIS_HOT := 0x40
		ctl := d.ctl
		disabled := state & CDIS_DISABLED, hot := state & CDIS_HOT, pressed := state & CDIS_SELECTED, focus := state & CDIS_FOCUS
		p := Theme.Palette
		if d.primary
			fill := p["accent"], border := p["accent"], text := p["accentText"]
		else
			fill := p["surfaceAlt"], border := p["border"], text := p["text"]
		if disabled
			fill := p["surfaceAlt"], border := p["border"], text := p["muted"]
		else if pressed
			fill := Theme.Mix(fill, 0x000000, 0.15)
		else if hot
			fill := Theme.Mix(fill, Theme.IsDark ? 0xFFFFFF : 0x000000, 0.08)
		if (focus && !disabled)
			border := d.primary ? Theme.Mix(p["accent"], Theme.IsDark ? 0xFFFFFF : 0x000000, 0.35) : p["accent"]
		Theme.PaintRoundRect(hdc, rc, fill, border, Theme.RgbFromGui(ctl.Gui), Round(4 * Theme.Scale))
		Theme.PaintText(hdc, ctl, rc, text, 0x1 | 0x4 | 0x20 | 0x100000, 0)      ; DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_HIDEPREFIX
	}

	static DrawCheck(d, hdc, rc, state) {
		static CDIS_DISABLED := 4, CDIS_HOT := 0x40, CDIS_FOCUS := 0x10, BM_GETCHECK := 0xF0
		ctl := d.ctl
		disabled := state & CDIS_DISABLED, hot := state & CDIS_HOT, focus := state & CDIS_FOCUS
		checked := SendMessage(BM_GETCHECK, 0, 0, ctl.Hwnd)
		p := Theme.Palette
		bg := Theme.RgbFromGui(ctl.Gui)
		; whole control background
		Theme.FillRect(hdc, rc, bg)
		box := Round(16 * Theme.Scale)
		l := NumGet(rc, 0, "Int"), t := NumGet(rc, 4, "Int"), b := NumGet(rc, 12, "Int")
		by := t + ((b - t) - box) // 2
		brc := Buffer(16)
		NumPut("Int", l, "Int", by, "Int", l + box, "Int", by + box, brc)
		if checked
			fill := p["accent"], border := p["accent"]
		else
			fill := p["surfaceAlt"], border := (hot || focus) ? p["text"] : p["muted"]
		if disabled
			fill := p["surfaceAlt"], border := p["border"]
		Theme.PaintRoundRect(hdc, brc, fill, border, bg, Round(3 * Theme.Scale))
		if checked {
			pen := DllCall("CreatePen", "Int", 0, "Int", Max(2, Round(2 * Theme.Scale)), "UInt", Theme.ToBgr(disabled ? p["muted"] : p["accentText"]), "Ptr")
			old := DllCall("SelectObject", "Ptr", hdc, "Ptr", pen, "Ptr")
			s := box / 16
			DllCall("MoveToEx", "Ptr", hdc, "Int", l + Round(3.5 * s), "Int", by + Round(8 * s), "Ptr", 0)
			DllCall("LineTo", "Ptr", hdc, "Int", l + Round(6.5 * s), "Int", by + Round(11 * s))
			DllCall("LineTo", "Ptr", hdc, "Int", l + Round(12.5 * s), "Int", by + Round(4.5 * s))
			DllCall("SelectObject", "Ptr", hdc, "Ptr", old, "Ptr"), DllCall("DeleteObject", "Ptr", pen)
		}
		trc := Buffer(16)
		NumPut("Int", l + box + Round(7 * Theme.Scale), "Int", t, "Int", NumGet(rc, 8, "Int"), "Int", b, trc)
		Theme.PaintText(hdc, ctl, trc, disabled ? p["muted"] : p["text"], 0x4 | 0x20 | 0x100000, 0)   ; DT_VCENTER | DT_SINGLELINE | DT_HIDEPREFIX
	}

	static RgbFromGui(g) {
		try return Integer("0x" g.BackColor)
		return Theme.Palette["bg"]
	}

	static FillRect(hdc, rc, rgb) {
		br := DllCall("CreateSolidBrush", "UInt", Theme.ToBgr(rgb), "Ptr")
		DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", br)
		DllCall("DeleteObject", "Ptr", br)
	}

	static PaintRoundRect(hdc, rc, fill, border, behind, radius) {
		Theme.FillRect(hdc, rc, behind)
		br := DllCall("CreateSolidBrush", "UInt", Theme.ToBgr(fill), "Ptr")
		pen := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", Theme.ToBgr(border), "Ptr")
		ob := DllCall("SelectObject", "Ptr", hdc, "Ptr", br, "Ptr"), op := DllCall("SelectObject", "Ptr", hdc, "Ptr", pen, "Ptr")
		DllCall("RoundRect", "Ptr", hdc, "Int", NumGet(rc, 0, "Int"), "Int", NumGet(rc, 4, "Int"), "Int", NumGet(rc, 8, "Int") - 1, "Int", NumGet(rc, 12, "Int") - 1, "Int", radius * 2, "Int", radius * 2)
		DllCall("SelectObject", "Ptr", hdc, "Ptr", ob, "Ptr"), DllCall("SelectObject", "Ptr", hdc, "Ptr", op, "Ptr")
		DllCall("DeleteObject", "Ptr", br), DllCall("DeleteObject", "Ptr", pen)
	}

	static PaintText(hdc, ctl, rc, rgb, flags, pad) {
		text := ""
		try text := ControlGetText(ctl.Hwnd)
		if (text = "")
			return
		hFont := SendMessage(0x31, 0, 0, ctl.Hwnd)          ; WM_GETFONT
		of := hFont ? DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr") : 0
		DllCall("SetBkMode", "Ptr", hdc, "Int", 1)          ; TRANSPARENT
		DllCall("SetTextColor", "Ptr", hdc, "UInt", Theme.ToBgr(rgb))
		DllCall("DrawTextW", "Ptr", hdc, "Str", text, "Int", -1, "Ptr", rc, "UInt", flags)
		if of
			DllCall("SelectObject", "Ptr", hdc, "Ptr", of, "Ptr")
	}

	; corner: 1 = none, 2 = round, 3 = small round (DWMWA_WINDOW_CORNER_PREFERENCE)
	static ApplyToGui(g, corner := 2, border := false) {
		g.BackColor := Theme.Hex("bg")
		g.SetFont("s10 c" Theme.Hex("text"), Theme.FontName)
		Theme.ApplyToHwnd(g.Hwnd, corner, border)
	}

	static AppIcon := 0        ; HICONs shown in title bars and Alt+Tab (the recolored app icon), set by setTrayIcon
	static AppIconSmall := 0

	static ApplyToHwnd(hwnd, corner := 2, border := false) {
		dark := Theme.IsDark ? 1 : 0
		if Theme.AppIcon && Theme.AppIconSmall
			try SendMessage(0x80, 1, Theme.AppIcon, hwnd), SendMessage(0x80, 0, Theme.AppIconSmall, hwnd)   ; WM_SETICON big + small
		try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 20, "Int*", dark, "UInt", 4)   ; DWMWA_USE_IMMERSIVE_DARK_MODE
		try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 33, "Int*", corner, "UInt", 4)  ; DWMWA_WINDOW_CORNER_PREFERENCE
		; title bar and frame follow a custom accent; with the Windows accent they are left to the system setting
		cap := Theme.CustomAccent ? Theme.Bgr("accent") : 0xFFFFFFFF, capText := Theme.CustomAccent ? Theme.Bgr("accentText") : 0xFFFFFFFF   ; DWMWA_COLOR_DEFAULT
		try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 34, "UInt*", border ? Theme.Bgr("border") : cap, "UInt", 4) ; DWMWA_BORDER_COLOR
		try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 35, "UInt*", cap, "UInt", 4)      ; DWMWA_CAPTION_COLOR
		try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 36, "UInt*", capText, "UInt", 4)  ; DWMWA_TEXT_COLOR
	}

	; Applies dark-mode visual styles to a control; call after g.Add.
	static StyleControl(ctl) {
		kind := ctl.Type
		styleName := Theme.IsDark ? "DarkMode_Explorer" : "Explorer"
		if (kind = "DDL" || kind = "ComboBox")
			styleName := Theme.IsDark ? "DarkMode_CFD" : "CFD"
		if (kind = "Edit" || kind = "Button" || kind = "ListBox" || kind = "ListView" || kind = "TreeView" || kind = "DDL" || kind = "ComboBox" || kind = "CheckBox" || kind = "Radio")
			try DllCall("uxtheme\SetWindowTheme", "Ptr", ctl.Hwnd, "Str", styleName, "Ptr", 0)
		if (kind = "Button")
			Theme.RegisterDraw(ctl, "button")
		if (kind = "CheckBox")
			Theme.RegisterDraw(ctl, "check")
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

; NM_CUSTOMDRAW from registered buttons and check boxes: paint them and skip the system drawing
Theme_OnNotify(wParam, lParam, msg, hwnd) {
	static NM_CUSTOMDRAW := -12, CDDS_PREPAINT := 1, CDRF_SKIPDEFAULT := 4
	if (NumGet(lParam, A_PtrSize * 2, "Int") != NM_CUSTOMDRAW)
		return
	from := NumGet(lParam, 0, "Ptr")
	if !Theme.drawn.Has(from)
		return
	if (NumGet(lParam, A_PtrSize * 3, "UInt") != CDDS_PREPAINT)
		return 0                                   ; CDRF_DODEFAULT for the erase stages; everything is painted at PREPAINT
	d := Theme.drawn[from]
	if !Theme_ControlAlive(d.ctl) {
		Theme.UnregisterDraw(from)
		return
	}
	hdc := NumGet(lParam, A_PtrSize * 4, "Ptr")
	rc := lParam + A_PtrSize * 5
	state := NumGet(lParam, A_PtrSize * 5 + 16 + A_PtrSize, "UInt")
	try {
		if (d.kind = "button")
			Theme.DrawButton(d, hdc, rc, state)
		else if (d.kind = "pill")
			Theme.DrawPill(d, hdc, rc, state)
		else
			Theme.DrawCheck(d, hdc, rc, state)
	}
	return CDRF_SKIPDEFAULT
}

; popups: every hit is client, so the invisible thick frame never shows a resize cursor or lets the user resize
Theme_OnNcHitTest(wParam, lParam, msg, hwnd) {
	if Theme.popups.Has(hwnd)
		return 1      ; HTCLIENT
}

; popups: WM_NCCALCSIZE returning 0 hands the whole window rectangle to the client, so the thick frame is
; invisible and takes no space while DWM still paints its shadow
Theme_OnNcCalcSize(wParam, lParam, msg, hwnd) {
	if Theme.popups.Has(hwnd)
		return 0
}

Theme_ControlAlive(ctl) {
	try return ctl.Hwnd ? true : false
	catch
		return false
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
